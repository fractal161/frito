`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

//`define DEBUG

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

`ifndef DEBUG
  `ifdef SYNTHESIS
    `define NOT_DEBUG_AND_SYNTHESIS
  `endif
`endif

module top_level(
  input wire clk_100mhz, //crystal reference clock
  input wire [15:0] sw, //all 16 input slide switches
  input wire [3:0] btn, //all four momentary button switches
  input wire [7:0] pmoda, //rows of matrix keypad
  output logic [7:0] pmodb, //cols of matrix keypad
  output logic [15:0] led, //16 green output LEDs (located right above switches)
  output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
  output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
  output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
  output logic [6:0] ss1_c, //cathod controls for the segments of lower four digits
  output logic [2:0] rgb0, //rgb led
  output logic [2:0] rgb1, //rgb led
  output logic [2:0] hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
  output logic [2:0] hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
  output logic spkl, spkr, //speaker outputs
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

  localparam int VIDEO_MEM_TYPE_RAM = 0;
  localparam int VIDEO_MEM_TYPE_VRAM = 1;
  localparam int VIDEO_MEM_TYPE_COUNT = 2;

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

  `ifdef SYNTHESIS
    BUFG mbf (.I(clk_100mhz), .O(clk_100mhz_buf));
  `else
    assign clk_100mhz_buf = clk_100mhz;
  `endif

  // chip-8 stuff! (TODO: fill out)

  localparam int CHIP8_CLK_RATIO = 200_000;
  // inline clock for simplicity
  logic chip8_clk;
  logic [17:0] chip8_clk_ctr;
  `ifdef SYNTHESIS
    localparam DEBOUNCE_TIME_MS = 5;
  `else
    localparam DEBOUNCE_TIME_MS = 0.000001;
  `endif
  `ifdef NOT_DEBUG_AND_SYNTHESIS
    // actual counter
    always_ff @(posedge clk_100mhz_buf)begin
      if (sys_rst)begin
        chip8_clk <= 0;
        chip8_clk_ctr <= 0;
      end else begin
        if (chip8_clk_ctr == CHIP8_CLK_RATIO-1) begin
          chip8_clk <= 1;
          chip8_clk_ctr <= 0;
        end else begin
          chip8_clk <= 0;
          chip8_clk_ctr <= chip8_clk_ctr+1;
        end
      end
    end
  `else
    // debug clock, for testing. btn[1] advances by a cycle
    logic btn_held;
    logic btn_pulse;
    logic prev_btn_held;
    debouncer #(.DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS)) btn1_db(
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
  `endif

  logic [15:0] mem_data;

  logic [11:0] proc_mem_addr;
  logic proc_mem_we;
  logic proc_mem_valid_req;
  logic [15:0] proc_mem_data;
  logic [$clog2(PROC_MEM_TYPE_COUNT)-1:0] proc_mem_type;
  logic proc_mem_size;

  logic proc_mem_ready;
  logic proc_mem_valid_res;

  logic [15:0] video_mem_addr;
  logic video_mem_we;
  logic video_mem_valid_req;
  logic [15:0] video_mem_data;
  logic [$clog2(VIDEO_MEM_TYPE_COUNT)-1:0] video_mem_type;

  logic video_mem_ready;
  logic video_mem_valid_res;

  logic [11:0] debug_mem_addr;
  logic debug_mem_we;
  logic debug_mem_valid_req;
  logic [15:0] debug_mem_data;
  logic [$clog2(DEBUG_MEM_TYPE_COUNT)-1:0] debug_mem_type;

  logic debug_mem_ready;
  logic debug_mem_valid_res;

  logic video_draw_sprite;
  logic [11:0] video_sprite_addr;
  logic [5:0] video_sprite_x;
  logic [4:0] video_sprite_y;
  logic [3:0] video_sprite_height;

  logic video_clear_buffer;

  logic video_collision;
  logic video_done_drawing;


  logic [15:0] hdmi_addr;
  logic [7:0] hdmi_mem_data;

  logic [15:0] input_keys;
  logic [15:0] keys_db; // debounced
  logic clk_60hz;

  // TODO: fill out params as needed
  chip8_memory #(.FILE(`FPATH(key_test.mem))) mem(
      .clk_in(clk_100mhz_buf),
      .hdmi_clk_in(clk_pixel),
      .rst_in(sys_rst),

      .proc_addr_in(proc_mem_addr),
      .proc_we_in(proc_mem_we),
      .proc_valid_in(proc_mem_valid_req),
      .proc_data_in(proc_mem_data),
      .proc_type_in(proc_mem_type),
      .proc_size_in(proc_mem_size),

      .video_addr_in(video_mem_addr),
      .video_we_in(video_mem_we),
      .video_valid_in(video_mem_valid_req),
      .video_data_in(video_mem_data),
      .video_type_in(video_mem_type),

      .debug_addr_in(debug_mem_addr),
      .debug_we_in(debug_mem_we),
      .debug_valid_in(debug_mem_valid_req),
      .debug_data_in(debug_mem_data),
      .debug_type_in(debug_mem_type),

      .hdmi_addr_in(hdmi_addr),

      .proc_ready_out(proc_mem_ready),
      .proc_valid_out(proc_mem_valid_res),

      .video_ready_out(video_mem_ready),
      .video_valid_out(video_mem_valid_res),

      .debug_ready_out(debug_mem_ready),
      .debug_valid_out(debug_mem_valid_res),

      .data_out(mem_data),

      .hdmi_data_out(hdmi_mem_data)
    );

  chip8_input input_module (
    .clk_in(clk_100mhz_buf),
    .rst_in(sys_rst),
    .row_vals(pmoda[3:0]),
    .col_vals(pmodb[3:0]),
    .key_pressed_out(input_keys)
    );

  logic [15:0] keys;
  assign keys = input_keys;

  genvar i;
  generate
    for (i = 0; i < 16; i=i+1)begin : g_keypad
      debouncer #(.DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS)) keypad_db(
          .clk_in(clk_100mhz_buf),
          .rst_in(sys_rst),
          .dirty_in(keys[i]),
          .clean_out(keys_db[i])
        );
    end
  endgenerate

  assign led = keys_db;

  logic active_audio;
  logic audio_out;

  logic active_processor;
  always_ff @(posedge clk_100mhz_buf)begin
    if (sys_rst)begin
      active_processor <= 0; // TODO: don't forget to set
    end
  end

  chip8_processor processor (
      .clk_in(clk_100mhz_buf),
      .rst_in(sys_rst),

      .chip8_clk_in(chip8_clk),

      .active_in(active_processor), // TODO: replace
      .timer_decr_in(clk_60hz),
      .key_state_in(keys_db),

      //.any_key_in(),
      //.valid_key_in(),
      //.req_key_state_in(),

      .mem_ready_in(proc_mem_ready),
      .mem_valid_in(proc_mem_valid_res),
      .mem_data_in(mem_data),

      .collision_in(video_collision),
      .done_drawing_in(video_done_drawing),

      //.req_key_out(),

      .mem_addr_out(proc_mem_addr),
      .mem_we_out(proc_mem_we),
      .mem_valid_out(proc_mem_valid_req),
      .mem_data_out(proc_mem_data),
      .mem_type_out(proc_mem_type),
      .mem_size_out(proc_mem_size),

      .draw_sprite_out(video_draw_sprite),
      .sprite_addr_out(video_sprite_addr),
      .sprite_x_out(video_sprite_x),
      .sprite_y_out(video_sprite_y),
      .sprite_height_out(video_sprite_height),

      .clear_buffer_out(video_clear_buffer),

      .active_audio_out(active_audio)
      //.error_out()
    );


  chip8_audio audio (
     .clk_in(clk_100mhz_buf),
     .rst_in(sys_rst),
     .active_in(active_audio),
     .timbre_in(sw[1:0]),
     //.pitch_in(750),
     .vol_in(sw[15:13]),
     .level_out(audio_out)
   );

  assign spkl = audio_out;
  assign spkr = audio_out;

  chip8_video video (
      .clk_in(clk_100mhz_buf),
      .rst_in(sys_rst),

      .draw_sprite_in(video_draw_sprite),
      .sprite_addr_in(video_sprite_addr),
      .sprite_x_in(video_sprite_x),
      .sprite_y_in(video_sprite_y),
      .sprite_height_in(video_sprite_height),

      .clear_buffer_in(video_clear_buffer),

      .mem_valid_in(video_mem_valid_res),
      .mem_ready_in(video_mem_ready),
      .mem_data_in(mem_data),

      .mem_addr_out(video_mem_addr),
      .mem_we_out(video_mem_we),
      .mem_valid_out(video_mem_valid_req),
      .mem_data_out(video_mem_data),
      .mem_type_out(video_mem_type),

      .collision_out(video_collision),
      .done_drawing_out(video_done_drawing)
    );

  // DEBUG stuff

  //logic debug_ff;

  //assign led[0] = debug_ff;

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
  `ifdef SYNTHESIS
    hdmi_clk_wiz_720p mhdmicw (
        .reset(0),
        .locked(locked),
        .clk_ref(clk_100mhz_buf),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x)
      );
  `endif

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

  logic [1:0] clk_60hz_tmp;

  // 60hz clock fifo
  always @(posedge clk_pixel)begin
    if (sys_rst) begin
      clk_60hz_tmp <= 0;
      clk_60hz <= 0;
    end else begin
      {clk_60hz, clk_60hz_tmp} <= {clk_60hz_tmp, new_frame};
    end
  end

  logic [7:0] red, green, blue; //red green and blue pixel values for output
  logic [7:0] chip8_red, chip8_green, chip8_blue; //red green and blue pixel values for output
  video_multiplexer multiplexer1(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_in(hcount),
      .vcount_in(vcount),

      .grid_in(1'b1),

      .hdmi_data_in(hdmi_mem_data),
      .hdmi_addr_out(hdmi_addr),
      .hdmi_red_out(chip8_red),
      .hdmi_green_out(chip8_green),
      .hdmi_blue_out(chip8_blue)
    );

  logic [23:0] config_pixel;
  config_video confiv_video(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_in(hcount),
      .vcount_in(vcount),
      .pixel_out(config_pixel)
    );

  always_comb begin
    red = active_processor ? chip8_red : config_pixel[23:16];
    green = active_processor ? chip8_green : config_pixel[15:8];
    blue = active_processor ? chip8_blue : config_pixel[7:0];
  end

  // pipeline active_draw, hor_sync, vert_sync by 2 cycles
  logic [10:0] hcount_piped;
  logic [9:0] vcount_piped;
  logic active_draw_piped;
  logic hor_sync_piped;
  logic vert_sync_piped;

  pipeline #(.WIDTH(3), .DEPTH(4)) video_signal_pipe(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .val_in({active_draw, hor_sync, vert_sync}),
      .val_out({active_draw_piped, hor_sync_piped, vert_sync_piped})
    );

  logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
  logic tmds_signal [2:0]; //output of each TMDS serializer!

  //three tmds_encoders (blue, green, red)
  tmds_encoder tmds_red(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(red),
      .control_in(2'b0),
      .ve_in(active_draw_piped),
      .tmds_out(tmds_10b[2])
    );

  tmds_encoder tmds_green(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(green),
      .control_in(2'b0),
      .ve_in(active_draw_piped),
      .tmds_out(tmds_10b[1])
    );

  tmds_encoder tmds_blue(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(blue),
      .control_in({vert_sync_piped, hor_sync_piped}),
      .ve_in(active_draw_piped),
      .tmds_out(tmds_10b[0])
    );

  //three tmds_serializers (blue, green, red):
  `ifdef SYNTHESIS
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
  `endif

  //output buffers generating differential signals:
  //three for the r,g,b signals and one that is at the pixel clock rate
  //the HDMI receivers use recover logic coupled with the control signals
  //asserted during blanking and sync periods to synchronize their faster bit
  //clocks off of the slower pixel clock (so they can recover a clock of about
  //742.5 MHz from the slower 74.25 MHz clock)
  `ifdef SYNTHESIS
    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));
  `endif

endmodule // top_level
`default_nettype wire
