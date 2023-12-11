`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Main processor module.
module config_state(
    input wire clk_in,
    input wire rst_in,

    // TODO: inputs for manipulating state
    input wire [15:0] key_state_in,

    //output logic chip8_clk_out, // rate at which to execute chip8 instructions

    output logic write_valid_out,
    output logic [9:0] write_addr_out,
    output logic [7:0] write_data_out,

    output logic [3:0] ptr_index_out,

    output logic active_processor_out,
    output logic [3:0] game_out, // which program to load

    output logic [4:0] rows_out,
    output logic [4:0] cols_out,

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

      rows_out <= 1;
      cols_out <= 1;

      bg_r <= 4'h0;
      bg_g <= 4'h0;
      bg_b <= 4'h0;

      fg_r <= 4'h8;
      fg_g <= 4'hF;
      fg_b <= 4'hD;

      timbre_out <= 0;
      pitch_out <= 0;
      vol_out <= 3'h7;
      write_valid_out <= 0;
    end else begin
      case (state)
        IDLE: begin
          write_valid_out <= 0;
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
          end else if (key_presses[4])begin
            case(ptr_index_out)
              4'd0: begin
              end
              4'd1: begin
                rows_out <= (rows_out == 1) ? 8 : rows_out - 1;
              end
              4'd2: begin
                cols_out <= (cols_out == 1) ? 8 : cols_out - 1;
              end
              4'd3: begin
                bg_r <= bg_r-1;
              end
              4'd4: begin
                bg_g <= bg_g-1;
              end
              4'd5: begin
                bg_b <= bg_b-1;
              end
              4'd6: begin
                fg_r <= fg_r-1;
              end
              4'd7: begin
                fg_g <= fg_g-1;
              end
              4'd8: begin
                fg_b <= fg_b-1;
              end
              4'd9: begin
              end
              4'd10: begin
              end
              4'd11: begin
                vol_out <= vol_out-1;
              end
              default: begin
              end
            endcase
            state <= WRITE;
          end else if (key_presses[6])begin
            case(ptr_index_out)
              4'd0: begin
              end
              4'd1: begin
                rows_out <= (rows_out == 8) ? 1 : rows_out + 1;
              end
              4'd2: begin
                cols_out <= (cols_out == 8) ? 1 : cols_out + 1;
              end
              4'd3: begin
                bg_r <= bg_r+1;
              end
              4'd4: begin
                bg_g <= bg_g+1;
              end
              4'd5: begin
                bg_b <= bg_b+1;
              end
              4'd6: begin
                fg_r <= fg_r+1;
              end
              4'd7: begin
                fg_g <= fg_g+1;
              end
              4'd8: begin
                fg_b <= fg_b+1;
              end
              4'd9: begin
              end
              4'd10: begin
              end
              4'd11: begin
                vol_out <= vol_out+1;
              end
              default: begin
              end
            endcase
            state <= WRITE;
          end
        end
        WRITE: begin
          case (ptr_index_out)
            4'd0: begin
              state <= IDLE;
            end
            4'd1: begin
              write_valid_out <= 1;
              write_addr_out <= 219;
              write_data_out <= rows_out;
              state <= IDLE;
            end
            4'd2: begin
              write_valid_out <= 1;
              write_addr_out <= 299;
              write_data_out <= cols_out;
              state <= IDLE;
            end
            4'd3: begin
              write_valid_out <= 1;
              write_addr_out <= 379;
              write_data_out <= bg_r;
              state <= IDLE;
            end
            4'd4: begin
              write_valid_out <= 1;
              write_addr_out <= 459;
              write_data_out <= bg_g;
              state <= IDLE;
            end
            4'd5: begin
              write_valid_out <= 1;
              write_addr_out <= 539;
              write_data_out <= bg_b;
              state <= IDLE;
            end
            4'd6: begin
              write_valid_out <= 1;
              write_addr_out <= 619;
              write_data_out <= fg_r;
              state <= IDLE;
            end
            4'd7: begin
              write_valid_out <= 1;
              write_addr_out <= 699;
              write_data_out <= fg_g;
              state <= IDLE;
            end
            4'd8: begin
              write_valid_out <= 1;
              write_addr_out <= 158;
              write_data_out <= fg_b;
              state <= IDLE;
            end
            4'd9: begin
              state <= IDLE;
            end
            4'd10: begin
              state <= IDLE;
            end
            4'd11: begin
              write_valid_out <= 1;
              write_addr_out <= 398;
              write_data_out <= vol_out;
              state <= IDLE;
            end
            default: begin
              state <= IDLE;
            end
          endcase
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
