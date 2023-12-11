`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Main processor module.
module config_state(
    input wire clk_in,
    input wire rst_in,

    // TODO: inputs for manipulating state
    input wire [15:0] key_state_in,

    //output logic chip8_clk_out, // rate at which to execute chip8 instructions

    output logic [3:0] ptr_index_out,

    output logic active_processor_out,
    output logic [3:0] game_out, // which program to load

    output logic [23:0] bg_color_out,
    output logic [23:0] fg_color_out,

    output logic [1:0] timbre_out,
    output logic pitch_out,
    output logic [2:0] vol_out
  );

  localparam int NUM_ROWS = 13;

  localparam int IDLE = 0;
  localparam int WRITE = 1;
  logic [1:0] state;

  logic [3:0] bg_r;
  logic [3:0] bg_g;
  logic [3:0] bg_b;

  logic [3:0] fg_r;
  logic [3:0] fg_g;
  logic [3:0] fg_b;

  logic [15:0] prev_key_state;
  logic [15:0] key_presses;

  assign key_presses = key_state_in & ~prev_key_state;

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      ptr_index_out <= 0;
      active_processor_out <= 0;

      bg_r <= 4'h0;
      bg_g <= 4'h0;
      bg_b <= 4'h0;

      bg_r <= 4'h8;
      bg_g <= 4'hF;
      bg_b <= 4'hD;

      timbre_out <= 0;
      pitch_out <= 0;
      vol_out <= 3'h7;
    end else begin
      case (state)
        IDLE: begin
          if (key_presses[5])begin
            if (ptr_index_out == 0)begin
              ptr_index_out <= NUM_ROWS-1;
            end else begin
              ptr_index_out <= ptr_index_out-1;
            end
          end else if (key_presses[8])begin
            if (ptr_index_out == NUM_ROWS-1)begin
              ptr_index_out <= 0;
            end else begin
              ptr_index_out <= ptr_index_out+1;
            end
          end else if (key_presses[0])begin
            if (ptr_index_out == NUM_ROWS-1)begin
              active_processor_out <= 1;
            end
          end
        end
        WRITE: begin
        end
        default: begin
        end
      endcase
    end
    prev_key_state <= key_state_in;
  end

  assign bg_color_out = {bg_r, bg_r, bg_g, bg_g, bg_b, bg_b};
  assign fg_color_out = {fg_r, fg_r, fg_g, fg_g, fg_b, fg_b};

endmodule

`default_nettype wire
