`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Main processor module.
module config_video(
    input wire clk_in,
    input wire rst_in,

    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    // TODO: inputs defining current menu state (i.e. what to show)
    output logic [23:0] pixel_out
  );

endmodule

`default_nettype wire
