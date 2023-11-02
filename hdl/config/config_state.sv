`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Main processor module.
module config_state(
    input wire clk_in,
    input wire rst_in,

    // TODO: inputs for manipulating state

    output logic chip8_clk_out, // rate at which to execute chip8 instructions

    output logic prog_sel_out, // which program to load

    output logic [23:0] light_color_out,
    output logic [23:0] dark_color_out,

    output logic timbre_out,
    output logic pitch_out,
    output logic vol_out
  );

endmodule

`default_nettype wire
