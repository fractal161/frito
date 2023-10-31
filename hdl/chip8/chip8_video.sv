`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// This module is responsible for handling the graphics of a single chip-8
// processor (i.e. NOT the multiplexer). It uses double buffering to prevent
// screen tearing
module chip8_video(
    input wire clk_in,
    input wire rst_in,

    // request so video modules know what to draw
    input wire [5:0] pixel_x_in,
    input wire [4:0] pixel_y_in,

    // for double buffering
    input wire ad_in,

    // sprite drawing info
    input logic [11:0] sprite_addr_in,
    input logic [10:0] sprite_pos_in,

    // receive sprite data from memory
    input wire mem_valid_in,
    input wire [1:0] mem_in,

    // config (TODO: is light color 0 or 1?)
    input wire [23:0] light_color_in,
    input wire [23:0] dark_color_in,

    // value of pixel at indicated location
    output logic pixel_out,

    // fetch sprite data from memory
    output logic [11:0] mem_addr_out
  );

  // pixel data is red from main buffer, sprite edits are always made to the
  // second buffer. when ad is low, second buffer is copied over to main
  logic [2047:0] main_buffer;
  logic [2047:0] second_buffer;

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
    end else begin
    end
  end

endmodule // top_level

`default_nettype wire
