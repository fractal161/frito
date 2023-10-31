`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Converts raw signal from keypad into input
module chip8_input(
    input wire clk_in,
    input wire rst_in,

    // TODO: figure out what inputs to put here
    output wire [3:0] any_key_out,
    output wire valid_key_out,
    output wire req_key_state_out
  );
  // TODO: implement here (might be purely combinational??)
endmodule // input

`default_nettype wire
