`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

// TODO: this currently assumes the debug version (also BUFs and OBUFDS's
// don't work so this needs to be commented out when running tests)
module chip8_tb;
  logic clk_in;
  logic [3:0] btn_in;

  top_level uut(
      .clk_100mhz(clk_in),
      .btn(btn_in)
    );

  always begin
    #5;
    clk_in = !clk_in;
  end

  initial begin
    $dumpfile("chip8.vcd");
    $dumpvars(0, chip8_tb);
    $display("Beginning simulation...");
    clk_in = 0;
    btn_in = 1;
    #20;
    btn_in = 0;
    #20;
    btn_in[1] = 1;
    #10;
    btn_in[1] = 0;
    #5000;
    btn_in[1] = 1;
    #10;
    btn_in[1] = 0;
    #5000;
    btn_in[1] = 1;
    #10;
    btn_in[1] = 0;
    #5000;
    btn_in[1] = 1;
    #10;
    btn_in[1] = 0;
    #5000;
    btn_in[1] = 1;
    #10;
    btn_in[1] = 0;
    #5000;
    btn_in[1] = 1;
    #10;
    btn_in[1] = 0;
    #5000;
    btn_in[1] = 1;
    #10;
    btn_in[1] = 0;
    #5000;
    btn_in[1] = 1;
    #10;
    btn_in[1] = 0;
    #5000;
    $display("Simulation complete!");
    $finish;
  end
endmodule

`default_nettype wire
