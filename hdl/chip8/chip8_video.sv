`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// This module is responsible for handling the graphics of a single chip-8
// processor (i.e. NOT the multiplexer). It uses double buffering to prevent
// screen tearing
module chip8_video(
    input wire clk_in,
    input wire rst_in,

    // for double buffering
    input wire ad_in,

    // requested pixel location
    input wire [5:0] pixel_x_in,
    input wire [4:0] pixel_y_in,
    // value of pixel at indicated location
    output logic pixel_out,

    // sprite drawing info
    input wire [11:0] sprite_addr_in,
    input wire [5:0] sprite_x_in,
    input wire [4:0] sprite_y_in,
    input wire [3:0] sprite_height_in, // 1 to 15

    input wire clear_buffer_in,

    // interfacing with memory
    input wire mem_valid_in,
    input wire mem_ready_in,
    input wire [7:0] mem_data_in,

    output logic [11:0] mem_addr_out,
    output logic mem_we,
    output logic mem_valid,
    output logic [7:0] mem_data_out,
    output logic mem_type_out // 0 for RAM (sprite), 1 for VRAM
  );

  // pixel data is read from main buffer, sprite edits are always made to the
  // second buffer. when ad is low, second buffer is copied over to main
  // TODO: if we support 128x64, this gets pretty big, so maybe reimplement
  // as BRAM
  localparam WIDTH = 64;
  localparam HEIGHT = 32;
  localparam BYTE_WIDTH = 8;

  localparam RESTING = 0;
  localparam DRAWING = 1;
  localparam CLEARING = 2;
  logic [1:0] state;

  logic [2:0] drawing_state;

  logic [11:0] sprite_addr;
  logic [5:0] sprite_pos_x;
  logic [4:0] sprite_pos_y;
  logic [3:0] sprite_height;

  logic [15:0] updating_line;

  logic [7:0] clear_pos; // Ranges from 0 to 8*32 for now 

  pipeline #(.WIDTH(7), .DEPTH(2)) draw_offset_pipe(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .val_in(draw_offset),
    .val_out(draw_offset_lagged)
  );

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      state <= RESTING;
    end else if (clear_buffer_in) begin
      state <= CLEARING;
      clear_pos <= 0;
    end else begin
      case (state)
        RESTING: begin
          if (mem_valid_in) begin
            sprite_addr <= sprite_addr_in;
            sprite_pos_x <= sprite_x_in;
            sprite_pos_y <= sprite_y_in;
            sprite_height <= sprite_height_in;
            state <= DRAWING;
          end
          draw_offset <= 0;
          drawing_state <= 0;
        end
        DRAWING: begin // Wrap-around in both x and y
          if (mem_ready_in) begin
            case (drawing_state)
              0: begin // Get sprite byte
              end
              1: begin // Get left buffer byte
              end
              2: begin // Get right buffer byte
              end
              3: begin // Write left buffer byte
              end
              4: begin // Write right buffer byte
                if (draw_offset < sprite_height) begin
                  draw_offset <= draw_offset + 1;
                end else begin
                  draw_offset <= 0;
                  state <= RESTING
                end
              end
            endcase

            
          end

          if (draw_offset_lagged == 119) state <= RESTING;
        end
        CLEARING: begin
          if (mem_ready_in) begin
            // Set byte in BRAM to 00000000
            mem_data_out <= 8'b00000000;
            mem_valid <= 1;
            mem_we <= 1;
            mem_type_out <= 1;
            mem_addr_out <= clear_pos;

            if (clear_pos >= BYTE_WIDTH*HEIGHT-1) state <= RESTING;
            clear_pos <= clear_pos + 1;
          end
        end
      endcase
    end
  end
  // TODO: If using a BRAM, will be seqential
  assign pixel_out = rst_in ? 0 : main_buffer[{pixel_y_in, pixel_x_in}];

endmodule // top_level

`default_nettype wire
