`timescale 1ns / 1ps
`default_nettype none

module chip8_audio_tb;
  logic clk_in;
  logic rst_in;

  logic [1:0] timbre;
  logic [9:0] tone;
  logic [2:0] vol;

  logic audio_out;




  chip8_audio uut(
    .clk_in(clk_in),
    .rst_in(rst_in),

    // controls when audio is being played
    .active_in(1'b1),

    // config
    .timbre_in(timbre), // TODO: e.g. sine, triangle, square waves
    .tone_in(tone), // TODO: decide how to represent
    .vol_in(vol), // TODO: decide how to represent

    // TODO: audio sample clock

    // signal as 8-bit value (TODO: signed or unsigned?)
    .level_out(audio_out)
    );

  always begin
    #5;
    clk_in = !clk_in;
  end

  initial begin
    $dumpfile("chip8_audio.vcd");
    $dumpvars(0, chip8_audio_tb);
    $display("Beginning simulation...");
    clk_in = 0;
    rst_in = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    #10;
    timbre = 2;
    tone = 750;
    vol = 2;
    #12000000;
    $display("Simulation complete!");
    $finish;
  end
endmodule