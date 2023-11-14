`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module chip8_video_tb;
  logic clk_in;
  logic rst_in;

  // TODO: other regs
  logic chip8_clk_in;
  logic [11:0] video_addr;
  logic video_we;
  logic video_valid_req;
  logic [7:0] video_data;
  logic [1:0] video_type;

  logic video_ready;
  logic video_valid_res;

  logic [7:0] data;

  logic clear_buffer;


  chip8_video uut(
      .clk_in(clk_in),
      .rst_in(rst_in),

      .draw_sprite_in(),
      .sprite_addr_in(),
      .sprite_x_in(),
      .sprite_y_in(),
      .sprite_height_in(),

      .clear_buffer_in(clear_buffer),

      .mem_data_in(data),
      .mem_ready_in(video_ready),
      .mem_valid_in(video_valid_res),

      .mem_addr_out(video_addr),
      .mem_we_out(video_we),
      .mem_valid_out(video_valid_req),
      .mem_data_out(video_data),
      .mem_type_out(video_type)
    );

  chip8_memory #(.FILE("data/ibm.mem")) mem(
      .clk_in(clk_in),
      .rst_in(rst_in),

      .proc_valid_in(1'b0),
      .debug_valid_in(1'b0),

      .video_addr_in(video_addr),
      .video_we_in(video_we),
      .video_valid_in(video_valid_req),
      .video_data_in(video_data),
      .video_type_in(video_type),

      .video_ready_out(video_ready),
      .video_valid_out(video_valid_res),

      .data_out(data)
    );

  always begin
    #5;
    clk_in = !clk_in;
  end

  initial begin
    $dumpfile("chip8_video.vcd");
    $dumpvars(0, chip8_video_tb);
    $display("Beginning simulation...");
    clk_in = 0;
    rst_in = 0;
    clear_buffer = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    #10;
    clear_buffer = 1;
    #10;
    clear_buffer = 0;
    #3000;
    $display("Simulation complete!");
    $finish;
  end
endmodule

`default_nettype wire
