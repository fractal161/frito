`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module chip8_processor_tb;
  logic clk_in;
  logic rst_in;

  // TODO: other regs
  logic chip8_clk_in;
  logic [11:0] proc_addr;
  logic proc_we;
  logic proc_valid_req;
  logic [7:0] proc_data;
  logic [1:0] proc_type;

  logic proc_ready;
  logic proc_valid_res;

  logic [7:0] data;


  chip8_processor uut(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .chip8_clk_in(chip8_clk_in),
      .active_in(1'b1),

      .mem_data_in(data),
      .mem_ready_in(proc_ready),
      .mem_valid_in(proc_valid_res),

      .mem_addr_out(proc_addr),
      .mem_we_out(proc_we),
      .mem_valid_out(proc_valid_req),
      .mem_data_out(proc_data),
      .mem_type_out(proc_type)
    );

  chip8_memory #(.FILE("data/ibm.mem")) mem(
      .clk_in(clk_in),
      .rst_in(rst_in),

      .video_valid_in(1'b0),
      .debug_valid_in(1'b0),

      .proc_addr_in(proc_addr),
      .proc_we_in(proc_we),
      .proc_valid_in(proc_valid_req),
      .proc_data_in(proc_data),
      .proc_type_in(proc_type),

      .proc_ready_out(proc_ready),
      .proc_valid_out(proc_valid_res),

      .data_out(data)
    );

  always begin
    #5;
    clk_in = !clk_in;
  end

  initial begin
    $dumpfile("chip8_processor.vcd");
    $dumpvars(0, chip8_processor_tb);
    $display("Beginning simulation...");
    clk_in = 0;
    rst_in = 0;
    chip8_clk_in = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    #10;
    chip8_clk_in = 1;
    #10;
    chip8_clk_in = 0;
    #500;
    chip8_clk_in = 1;
    #10;
    chip8_clk_in = 0;
    #500;
    chip8_clk_in = 1;
    #10;
    chip8_clk_in = 0;
    #500;
    chip8_clk_in = 1;
    #10;
    chip8_clk_in = 0;
    #500;
    chip8_clk_in = 1;
    #10;
    chip8_clk_in = 0;
    #500;
    chip8_clk_in = 1;
    #10;
    chip8_clk_in = 0;
    #500;
    $display("Simulation complete!");
    $finish;
  end
endmodule

`default_nettype wire
