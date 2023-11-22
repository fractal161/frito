`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module chip8_memory_tb;
  logic clk_in;
  logic rst_in;
  // TODO: other regs
  logic [11:0] debug_addr;
  logic debug_we;
  logic debug_valid;
  logic [1:0] debug_type;
  logic [15:0] data;


  // TODO: more than just debug
  chip8_memory #(.FILE("data/ibm.mem")) uut(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .proc_valid_in(1'b0),
      .video_valid_in(1'b0),

      .debug_addr_in(debug_addr),
      .debug_we_in(debug_we),
      .debug_valid_in(debug_valid),
      .debug_type_in(debug_type),

      .data_out(data)
    );

  always begin
    #5;
    clk_in = !clk_in;
  end

  initial begin
    $dumpfile("chip8_memory.vcd");
    $dumpvars(0, chip8_memory_tb);
    $display("Beginning simulation...");
    clk_in = 0;
    rst_in = 0;
    // TODO: init regs

    debug_addr = 0;
    debug_we = 0;
    debug_valid = 0;
    debug_type = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    #10;
    debug_addr = 12'h201;
    debug_valid = 1;
    debug_type = 0;
    #10;
    debug_valid = 0;
    #30;
    $display("Simulation complete!");
    $finish;
  end
endmodule

`default_nettype wire
