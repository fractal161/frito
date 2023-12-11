`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Main processor module.
module config_state(
    input wire clk_in,
    input wire rst_in,

    // TODO: inputs for manipulating state
    input wire key_presses_in,

    //output logic chip8_clk_out, // rate at which to execute chip8 instructions

    output logic ptr_index_out,

    output logic active_processor_out,
    output logic [3:0] game_out, // which program to load

    output logic [23:0] bg_color_out,
    output logic [23:0] fg_color_out,

    output logic [1:0] timbre_out,
    output logic pitch_out,
    output logic [2:0] vol_out
  );

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      active_processor_out <= 0;
    end else begin
    end
  end

endmodule

`default_nettype wire
