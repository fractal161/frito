`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module top_level(
  input wire clk_100mhz, //crystal reference clock
  input wire [15:0] sw, //all 16 input slide switches
  input wire [3:0] btn, //all four momentary button switches
  output logic [15:0] led, //16 green output LEDs (located right above switches)
  output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
  output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
  output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
  output logic [6:0] ss1_c, //cathod controls for the segments of lower four digits
  output logic [2:0] rgb0, //rgb led
  output logic [2:0] rgb1, //rgb led
  output logic [2:0] hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
  output logic [2:0] hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
  output logic hdmi_clk_p, hdmi_clk_n //differential hdmi clock
  );

  // TODO: this should be in chip8_params why is it not imported here
  localparam int PROC_MEM_TYPE_RAM = 0;
  localparam int PROC_MEM_TYPE_REG = 1;
  localparam int PROC_MEM_TYPE_STK = 2;
  localparam int PROC_MEM_TYPE_COUNT = 3;

  localparam int DEBUG_MEM_TYPE_RAM = 0;
  localparam int DEBUG_MEM_TYPE_VRAM = 1;
  localparam int DEBUG_MEM_TYPE_REG = 2;
  localparam int DEBUG_MEM_TYPE_STK = 3;
  localparam int DEBUG_MEM_TYPE_COUNT = 4;

  // assign led = sw; //to verify the switch values

  //shut up those rgb LEDs (active high):
  assign rgb1 = 0;
  assign rgb0 = 0;
  /* have btn0 control system reset */
  logic sys_rst;
  assign sys_rst = btn[0];

  logic clk_pixel, clk_5x; //clock lines
  logic locked; //locked signal (we'll leave unused but still hook it up)

  logic clk_100mhz_buf;

  BUFG mbf (.I(clk_100mhz), .O(clk_100mhz_buf));

  // chip-8 stuff! (TODO: fill out)

  localparam int CHIP8_CLK_RATIO = 200_000;
  // inline clock for simplicity
  logic chip8_clk;
  logic [17:0] chip8_clk_ctr;
  // actual counter
  //always_ff @(posedge clk_100mhz_buf)begin
  //  if (sys_rst)begin
  //    chip8_clk <= 0;
  //    chip8_clk_ctr <= 0;
  //  end else begin
  //    if (chip8_clk_ctr == CHIP8_CLK_RATIO-1) begin
  //      chip8_clk <= 1;
  //      chip8_clk_ctr <= 0;
  //    end else begin
  //      chip8_clk <= 0;
  //      chip8_clk_ctr <= chip8_clk_ctr+1;
  //    end
  //  end
  //end
  // debug clock, for testing. btn[1] advances by a cycle
  logic btn_held;
  logic btn_pulse;
  logic prev_btn_held;
  debouncer btn1_db(
      .clk_in(clk_100mhz_buf),
      .rst_in(sys_rst),
      .dirty_in(btn[1]),
      .clean_out(btn_held)
    );
  always_ff @(posedge clk_100mhz_buf)begin
    btn_pulse <= btn_held & !prev_btn_held;
    prev_btn_held <= btn_held;
  end
  assign chip8_clk = btn_pulse;

  logic [7:0] mem_data;

  logic [11:0] proc_mem_addr;
  logic proc_mem_we;
  logic proc_mem_valid_req;
  logic [7:0] proc_mem_data;
  logic [$clog2(PROC_MEM_TYPE_COUNT)-1:0] proc_mem_type;

  logic proc_mem_ready;
  logic proc_mem_valid_res;

  logic [11:0] debug_mem_addr;
  logic debug_mem_we;
  logic debug_mem_valid_req;
  logic [7:0] debug_mem_data;
  logic [$clog2(DEBUG_MEM_TYPE_COUNT)-1:0] debug_mem_type;

  logic debug_mem_ready;
  logic debug_mem_valid_res;

  // TODO: fill out params as needed
  chip8_memory #(.FILE(`FPATH(ibm.mem))) mem(
      .clk_in(clk_100mhz_buf),
      .hdmi_clk_in(clk_pixel),
      .rst_in(sys_rst),

      .proc_addr_in(proc_mem_addr),
      .proc_we_in(proc_mem_we),
      .proc_valid_in(proc_mem_valid_req),
      .proc_data_in(proc_mem_data),
      .proc_type_in(proc_mem_type),

      //.video_addr_in(),
      //.video_we_in(),
      .video_valid_in(1'b0),
      //.video_data_in(),
      //.video_type_in(),

      .debug_addr_in(debug_mem_addr),
      .debug_we_in(debug_mem_we),
      .debug_valid_in(debug_mem_valid_req),
      .debug_data_in(debug_mem_data),
      .debug_type_in(debug_mem_type),

      //.hdmi_addr_in(),

      .proc_ready_out(proc_mem_ready),
      .proc_valid_out(proc_mem_valid_res),

      //.video_ready_out(),
      //.video_valid_out(),

      .debug_ready_out(debug_mem_ready),
      .debug_valid_out(debug_mem_valid_res),

      .data_out(mem_data)

      //.hdmi_data_out()
    );

  //chip8_input keys (
  //    .clk_in(clk_100mhz_buf),
  //    .rst_in(sys_rst)
  //  );

  chip8_processor processor (
      .clk_in(clk_100mhz_buf),
      .rst_in(sys_rst),

      .chip8_clk_in(chip8_clk),

      .active_in(1'b1), // TODO: replace
      //.timer_decr_in(),

      //.any_key_in(),
      //.valid_key_in(),
      //.req_key_state_in(),

      .mem_ready_in(proc_mem_ready),
      .mem_valid_in(proc_mem_valid_res),
      .mem_data_in(mem_data),

      //.req_key_out(),

      .mem_addr_out(proc_mem_addr),
      .mem_we_out(proc_mem_we),
      .mem_valid_out(proc_mem_valid_req),
      .mem_data_out(proc_mem_data),
      .mem_type_out(proc_mem_type)

      //.sprite_addr_out(),
      //.sprite_pos_out(),
      //.active_audio_out(),
      //.error_out()
    );

  //chip8_audio audio (
  //    .clk_in(clk_100mhz_buf),
  //    .rst_in(sys_rst)
  //  );


  //chip8_video video (
  //    .clk_in(clk_100mhz_buf),
  //    .rst_in(sys_rst),
  //  );

  // DEBUG stuff

  logic debug_ff;

  assign led[0] = debug_ff;

  localparam int DEBUG_CLK_RATIO = 1_000_000;
  logic [27:0] debug_clk_ctr;
  logic [31:0] debug_data;
  always_ff @(posedge clk_100mhz_buf)begin
    if (sys_rst)begin
      debug_data <= 0;
      debug_clk_ctr <= 0;
    end else begin
      if (debug_clk_ctr == DEBUG_CLK_RATIO-1) begin
        debug_clk_ctr <= 0;
        if (debug_mem_ready)begin
          debug_mem_addr <= sw[11:0];
          debug_mem_we <= 0;
          debug_mem_valid_req <= 1;
          debug_mem_type <= sw[15:16-$clog2(DEBUG_MEM_TYPE_COUNT)];
        end else begin
          debug_mem_valid_req <= 0;
        end
      end else begin
        debug_mem_valid_req <= 0;
        debug_clk_ctr <= debug_clk_ctr+1;
      end
      if (debug_mem_valid_res)begin
        debug_data <= mem_data;
      end
    end
  end

  logic [6:0] ss_c;
  seven_segment_controller ssc(
      .clk_in(clk_100mhz_buf),
      .rst_in(sys_rst),
      .val_in(debug_data),
      .cat_out(ss_c),
      .an_out({ss0_an, ss1_an})
    );
  assign ss0_c = ss_c;
  assign ss1_c = ss_c;

  // HDMI stuff

  //clock manager...creates 74.25 Hz and 5 times 74.25 MHz for pixel and TMDS
  hdmi_clk_wiz_720p mhdmicw (
      .reset(0),
      .locked(locked),
      .clk_ref(clk_100mhz_buf),
      .clk_pixel(clk_pixel),
      .clk_tmds(clk_5x)
    );

  logic [10:0] hcount; //hcount of system!
  logic [9:0] vcount; //vcount of system!
  logic hor_sync; //horizontal sync signal
  logic vert_sync; //vertical sync signal
  logic active_draw; //active draw! 1 when in drawing region.0 in blanking/sync
  logic new_frame; //one cycle active indicator of new frame of info!
  logic [5:0] frame_count; //0 to 59 then rollover frame counter

  //written by you! (make sure you include in your hdl)
  //default instantiation so making signals for 720p
  video_sig_gen mvg(
      .clk_pixel_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_out(hcount),
      .vcount_out(vcount),
      .vs_out(vert_sync),
      .hs_out(hor_sync),
      .ad_out(active_draw),
      .nf_out(new_frame),
      .fc_out(frame_count)
    );

  // TODO: put multiplexer here

  logic [7:0] red, green, blue; //red green and blue pixel values for output


  // TODO: assign (red, green, blue) here, which gets fed to output
  always_comb begin
    red = 8'h7F;
    green = 8'hFF;
    blue = 8'hD4;
  end

  logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
  logic tmds_signal [2:0]; //output of each TMDS serializer!

  //three tmds_encoders (blue, green, red)
  tmds_encoder tmds_red(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(red),
      .control_in(2'b0),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[2])
    );

  tmds_encoder tmds_green(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(green),
      .control_in(2'b0),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[1])
    );

  tmds_encoder tmds_blue(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(blue),
      .control_in({vert_sync, hor_sync}),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[0])
    );

  //three tmds_serializers (blue, green, red):
  tmds_serializer red_ser(
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst),
      .tmds_in(tmds_10b[2]),
      .tmds_out(tmds_signal[2])
    );

  tmds_serializer green_ser(
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst),
      .tmds_in(tmds_10b[1]),
      .tmds_out(tmds_signal[1])
    );

  tmds_serializer blue_ser(
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst),
      .tmds_in(tmds_10b[0]),
      .tmds_out(tmds_signal[0])
    );

  //output buffers generating differential signals:
  //three for the r,g,b signals and one that is at the pixel clock rate
  //the HDMI receivers use recover logic coupled with the control signals
  //asserted during blanking and sync periods to synchronize their faster bit
  //clocks off of the slower pixel clock (so they can recover a clock of about
  //742.5 MHz from the slower 74.25 MHz clock)
  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

endmodule // top_level
`default_nettype wire
