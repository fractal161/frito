`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Main processor module.
module config_state(
    input wire clk_in,
    input wire rst_in,

    input wire [15:0] key_state_in,

    input wire [7:0] menu_data_in,

    //output logic chip8_clk_out, // rate at which to execute chip8 instructions

    output logic [11:0] menu_addr_out,

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
    output logic [9:0] pitch_out,
    output logic [2:0] vol_out
  );

  localparam int NUM_ROWS = 13;

  localparam int NUM_GAMES = 6;
  localparam int GAME_ROW_OFFSET = 2048;
  localparam int TIMBRE_ROW_OFFSET = 2144;

  localparam int IDLE = 0;
  localparam int WRITE = 1;
  logic [1:0] state;

  logic [3:0] bg_r;
  logic [3:0] bg_g;
  logic [3:0] bg_b;

  logic [3:0] fg_r;
  logic [3:0] fg_g;
  logic [3:0] fg_b;

  logic [15:0] key_state_piped;
  pipeline #(.WIDTH(15), .DEPTH(4)) key_pipe(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .val_in(key_state_in),
      .val_out(key_state_piped)
    );

  logic [15:0] prev_key_state;
  logic [15:0] key_presses;

  assign key_presses = key_state_piped & ~prev_key_state;

  logic [9:0] pitches[7:0];
  logic [11:0] pitches_bcd[7:0];
  logic [9:0] pitch_tmp;
  logic [2:0] pitch_index;

  logic [3:0] menu_index;

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      ptr_index_out <= 0;
      active_processor_out <= 1; // TODO: set to 0 for final

      game_out <= 0;

      rows_out <= 1;
      cols_out <= 1;

      bg_r <= 4'h0;
      bg_g <= 4'h0;
      bg_b <= 4'h0;

      fg_r <= 4'h8;
      fg_g <= 4'hF;
      fg_b <= 4'hD;

      pitches[0] <= 10'd440;
      pitches[1] <= 10'd493;
      pitches[2] <= 10'd523;
      pitches[3] <= 10'd587;
      pitches[4] <= 10'd659;
      pitches[5] <= 10'd698;
      pitches[6] <= 10'd784;
      pitches[7] <= 10'd880;

      pitches_bcd[0] <= 12'h440;
      pitches_bcd[1] <= 12'h493;
      pitches_bcd[2] <= 12'h523;
      pitches_bcd[3] <= 12'h587;
      pitches_bcd[4] <= 12'h659;
      pitches_bcd[5] <= 12'h698;
      pitches_bcd[6] <= 12'h784;
      pitches_bcd[7] <= 12'h880;

      timbre_out <= 0;
      pitch_out <= 10'd440;
      pitch_index <= 0;
      vol_out <= 3'h7;
      write_valid_out <= 0;

      menu_index <= 0;
    end else begin
      if (!active_processor_out)begin
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
            active_processor_out <= 1;
          end else if (key_presses[4])begin
            case(ptr_index_out)
              4'd0: begin
                game_out <= (game_out == 0) ? NUM_GAMES - 1 : game_out - 1;
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
                timbre_out <= timbre_out-1;
              end
              4'd10: begin
                pitch_index <= pitch_index-1;
                pitch_out <= pitches[3'(pitch_index-1)];
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
                game_out <= (game_out == NUM_GAMES - 1) ? 0 : game_out + 1;
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
                timbre_out <= timbre_out+1;
              end
              4'd10: begin
                pitch_index <= pitch_index+1;
                pitch_out <= pitches[3'(pitch_index+1)];
              end
              4'd11: begin
                vol_out <= vol_out+1;
              end
              default: begin
              end
            endcase
            state <= WRITE;
            menu_index <= 0;
          end
        end
        WRITE: begin
          case (ptr_index_out)
            4'd0: begin
              // alternate between fetching and writing
              menu_addr_out <= GAME_ROW_OFFSET+(8'(game_out) << 4)+menu_index;
              if (menu_index > 2)begin
                write_valid_out <= 1;
                write_addr_out <= 125+menu_index;
                write_data_out <= menu_data_in;
              end else begin
                write_valid_out <= 0;
              end
              if (menu_index == 14)begin
                state <= IDLE;
                menu_index <= 0;
              end else begin
                menu_index <= menu_index + 1;
              end
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
              menu_addr_out <= TIMBRE_ROW_OFFSET+(4'(timbre_out) << 2)+menu_index;
              if (menu_index > 2)begin
                write_valid_out <= 1;
                write_addr_out <= 232+menu_index;
                write_data_out <= menu_data_in;
              end else begin
                write_valid_out <= 0;
              end
              if (menu_index == 6)begin
                state <= IDLE;
                menu_index <= 0;
              end else begin
                menu_index <= menu_index + 1;
              end
            end
            4'd10: begin
              case (menu_index)
                0: begin
                  write_valid_out <= 1;
                  write_addr_out <= 314;
                  write_data_out <= pitches_bcd[pitch_index][11:8];
                  menu_index <= 1;
                end
                1: begin
                  write_valid_out <= 1;
                  write_addr_out <= 315;
                  write_data_out <= pitches_bcd[pitch_index][7:4];
                  menu_index <= 2;
                end
                2: begin
                  write_valid_out <= 1;
                  write_addr_out <= 316;
                  write_data_out <= pitches_bcd[pitch_index][3:0];
                  state <= IDLE;
                  menu_index <= 0;
                end
                default: begin
                end
              endcase
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
    end
    prev_key_state <= key_state_piped;
  end

  assign bg_color_out = {bg_r, bg_r, bg_g, bg_g, bg_b, bg_b};
  assign fg_color_out = {fg_r, fg_r, fg_g, fg_g, fg_b, fg_b};

endmodule

`default_nettype wire
