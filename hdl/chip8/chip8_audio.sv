`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Plays audio ig
module chip8_audio(
    input wire clk_in,
    input wire rst_in,

    // controls when audio is being played
    input wire active_in,

    // config
    input wire timbre_in, // TODO: e.g. sine, triangle, square waves
    input wire pitch_in, // TODO: decide how to represent
    input wire vol_in, // TODO: decide how to represent

    // TODO: audio sample clock

    // signal as 8-bit value (TODO: signed or unsigned?)
    output logic [7:0] level_out
  );

  // TODO: put different waveform modules here

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
    end else begin
    end
  end
endmodule // input

`default_nettype wire
