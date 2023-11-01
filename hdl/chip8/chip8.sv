`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// combines all of the other modules together
module chip8(
    input wire clk_in,
    input wire rst_in

    // TODO: figure out inputs
    // TODO: figure out outputs
  );

  chip8_memory mem (
      .clk_in(clk_in),
      .rst_in(rst_in)
    );

  chip8_input keys (
      .clk_in(clk_in),
      .rst_in(rst_in)
    );

  chip8_processor processor (
      .clk_in(clk_in),
      .rst_in(rst_in)
    );

  chip8_audio audio (
      .clk_in(clk_in),
      .rst_in(rst_in)
    );


  chip8_video video (
      .clk_in(clk_in),
      .rst_in(rst_in)
    );

endmodule // chip8

`default_nettype wire
