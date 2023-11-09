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
    input wire [15:0] sprite_addr_in,
    input wire [5:0] sprite_x_in,
    input wire [4:0] sprite_y_in,
    input wire [3:0] sprite_height_in, // 1 to 15

    input wire clear_buffer_in,

    // interfacing with memory
    input wire mem_valid_in,
    input wire mem_ready_in,
    input wire [7:0] mem_data_in,

    output logic [15:0] mem_addr_out,
    output logic mem_we,
    output logic mem_valid_out,
    output logic [7:0] mem_data_out,
    output logic mem_type_out // 0 for RAM (sprite), 1 for VRAM
  );

  localparam WIDTH = 64;
  localparam HEIGHT = 32;
  localparam BYTE_WIDTH = 8;

  localparam RESTING = 0;
  localparam DRAWING = 1;
  localparam CLEARING = 2;
  logic [1:0] state;

  logic [2:0] drawing_state;
  logic [3:0] draw_offset;

  logic [15:0] sprite_addr;
  logic [5:0] sprite_pos_x;
  logic [4:0] sprite_pos_y;
  logic [2:0] left_byte;
  logic [2:0] right_byte;
  logic [3:0] right_offset;

  logic [3:0] sprite_height;

  logic [15:0] updating_line;

  logic [7:0] clear_pos; // Ranges from 0 to 8*32 for now 

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      state <= RESTING;
      mem_valid_out <= 0;
    end else if (clear_buffer_in) begin
      state <= CLEARING;
      clear_pos <= 0;
    end else begin
      case (state)
        RESTING: begin
          if (mem_valid_in) begin
            sprite_addr <= sprite_addr_in;
            sprite_pos_x <= sprite_x_in;
            left_byte <= (sprite_x_in >> 3);
            right_byte <= (sprite_x_in >> 3)+1; // does wrap-around
            left_offset <= sprite_x_in[2:0]; // equivalent to mod 8
            sprite_pos_y <= sprite_y_in;
            sprite_height <= sprite_height_in;
            state <= DRAWING;
          end
          draw_offset <= 0;
          drawing_state <= 0;
          updating_line <= 0;
          mem_valid_out <= 0;
        end

        DRAWING: begin // wrap-around in both x and y
          case (drawing_state)
            0: begin // request sprite byte
              if (mem_ready_in) begin
                mem_valid_out <= 1;
                mem_we <= 0; // read
                mem_type_out <= 0; // RAM
                mem_addr_out <= sprite_addr + draw_offset;
                drawing_state <= drawing_state + 1;
              end
            end
            1: begin // recieve sprite byte
              mem_valid_out <= 0;
              if (mem_valid_in) begin
                updating_line <= ({mem_data_in, 8'b00000000}) >> left_offset;
                drawing_state <= drawing_state + 1;
              end
            end
            2: begin // request left buffer byte
              if (mem_ready_in) begin
                mem_valid_out <= 1;
                mem_we <= 0; // read
                mem_type_out <= 1; // VRAM
                mem_addr_out <= {8'b00000000, (sprite_pos_y + draw_offset), left_byte}; // 
                drawing_state <= drawing_state + 1;
              end
            end
            3: begin // recieve left buffer byte
              mem_valid_out <= 0;
              if (mem_valid_in) begin
                updating_line[15:8] <= updating_line[15:8] ^ mem_data_in; // XOR!
                drawing_state <= drawing_state + 1;
                // TODO: Collisions
              end
            end
            4: begin // request right buffer byte
              if (mem_ready_in) begin
                mem_valid_out <= 1;
                mem_we <= 0; // read
                mem_type_out <= 1; // VRAM
                mem_addr_out <= {8'b00000000, (sprite_pos_y + draw_offset), right_byte}; // 8+5+3 = 16
                drawing_state <= drawing_state + 1;
              end
            end
            5: begin // recieve right buffer byte
              mem_valid_out <= 0;
              if (mem_valid_in) begin
                updating_line[7:0] <= updating_line[7:0] ^ mem_data_in; // XOR!
                drawing_state <= drawing_state + 1;
                // TODO: Collisions
              end
            end
            6: begin // write left buffer byte
              if (mem_ready_in) begin
                mem_data_out <= updating_line[15:8];
                mem_valid_out <= 1;
                mem_we <= 1; // write
                mem_type_out <= 1; // VRAM
                mem_addr_out <= {8'b00000000, (sprite_pos_y + draw_offset), left_byte};
                drawing_state <= drawing_state + 1;
              end else
                mem_valid_out <= 0;
              end
            end
            7: begin // write right buffer byte
              if (mem_ready_in) begin
                mem_data_out <= updating_line[7:0];
                mem_valid_out <= 1;
                mem_we <= 1; // write
                mem_type_out <= 1; // VRAM
                mem_addr_out <= {8'b00000000, (sprite_pos_y + draw_offset), right_byte};
              
                // Check if there is another line to draw
                if (draw_offset < sprite_height) begin
                  draw_offset <= draw_offset + 1;
                  drawing_state <= 0;
                end else begin
                  state <= RESTING
                end
              end else begin
                mem_valid_out <= 0;
              end
            end
          endcase
        end

        CLEARING: begin
          if (mem_ready_in) begin
            // Set byte in BRAM to 00000000
            mem_data_out <= 8'b00000000;
            mem_valid_out <= 1;
            mem_we <= 1; // write
            mem_type_out <= 1; // VRAM
            mem_addr_out <= {8'b00000000, clear_pos};

            if (clear_pos >= BYTE_WIDTH*HEIGHT-1) begin
              state <= RESTING;
            end
            
            clear_pos <= clear_pos + 1;
          end else begin
            mem_valid_out <= 0;
          end
        end
      endcase
    end
  end

endmodule // top_level

`default_nettype wire
