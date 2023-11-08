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
    input wire [11:0] sprite_addr_in,
    input wire [10:0] sprite_pos_in,

    // receive sprite data from memory
    input wire mem_valid_in,
    input wire [1:0] mem_in,

    input wire clear_buffer_in,

    // config (TODO: I think 0 is light, 1 is dark, but not sure)
    input wire [23:0] light_color_in,
    input wire [23:0] dark_color_in,

    // value of pixel at indicated location
    output logic pixel_out,

    // fetch sprite data from memory
    output logic [11:0] mem_addr_out
  );

  // pixel data is read from main buffer, sprite edits are always made to the
  // second buffer. when ad is low, second buffer is copied over to main
  // TODO: if we support 128x64, this gets pretty big, so maybe reimplement
  // as BRAM
  logic [2047:0] main_buffer;
  logic [2047:0] second_buffer;

  localparam RESTING = 0;
  localparam UPDATING = 1;
  localparam CLEARING = 2;
  logic[1:0] state;

  logic [11:0] sprite_addr;
  logic [5:0] sprite_pos_x;
  logic [4:0] sprite_pos_y;
  logic [6:0] draw_offset; // Ranges from 0 to 119
  logic [10:0] clear_pos;

  pipeline #(.WIDTH(7), .DEPTH(2)) draw_offset_pipe(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .val_in(draw_offset),
    .val_out(draw_offset_lagged)
  );

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      main_buffer <= 0;
      state <= RESTING;
    end else if (clear_buffer_in) begin
      state <= CLEARING;
      clear_pos <= 0;
    end else begin
      case (state)
        RESTING: begin
          if (mem_valid_in) begin
            sprite_addr <= sprite_addr_in;
            sprite_pos_x <= sprite_pos_in[5:0];
            sprite_pos_y <= sprite_pos_in[10:6];
            state <= UPDATING;
          end
          draw_offset <= 0;
        end
        UPDATING: begin
          // Query memory 2 cycles ahead of when its needed. How do we query memory?
          // TODO: Use draw_offset for memory addressing, draw_offset_lagged for updating
          if (draw_offset < 119) begin
            draw_offset <= draw_offset + 1;
          end else begin
            draw_offset <= 0;
          end

          if (draw_offset_lagged == 119) state <= RESTING;
        end
        CLEARING: begin
          // TODO
          main_buffer[clear_pos] <= 0;
          if (clear_pos == 2047) state <= RESTING;
          clear_pos <= clear_pos + 1;
        end
      endcase
    end
  end
  // TODO: If using a BRAM, will be seqential
  assign pixel_out = rst_in ? 0 : main_buffer[{pixel_y_in, pixel_x_in}];

endmodule // top_level

`default_nettype wire
