`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Converts raw signal from keypad into input
module chip8_input(
    input wire clk_in,
    input wire rst_in,

    // TODO: figure out what inputs to put here
    output wire [3:0] any_key_out,
    output wire valid_key_out,
    output wire req_key_state_out
  );
  // TODO: Debounce?

  // Strategy: pull individual columns to 0, then check which rows are 0
  // Currently takes 8 cycles to poll the keypad

  // Interface with keypad in this module?
  logic [3:0] col_vals;
  logic [3:0] row_vals;

  logic [1:0] polling_state; // 0 to 3

  logic polling_substate;
  localparam SETTING = 0;
  localparam READING = 1;

  logic [3:0] key_num_pressed; // 0 to 15
  logic key_pressed; // indicates whether a key has been pressed
  logic key_invalid; // indicates whether 2 or more keys pressed

  always_ff @(posedge clk_in) begin
        if (rst_in) begin
           polling_state <= 0;
           polling_substate <= SETTING;
           key_invalid <= 0;
           key_pressed <= 0;
        end else if (polling_substate == SETTING) begin
            // pull a column to 0
            case (polling_state)
                0: begin
                    // interpret results from previous polling
                    valid_key_out <= key_pressed & (~key_invalid);
                    any_key_out <= key_num_pressed;

                    // initialize stuff for this polling cycle
                    done_polling <= 0;
                    key_invalid <= 0;
                    key_pressed <= 0;

                    col_vals <= 4'b0111;
                end
                1: begin
                    col_vals <= 4'b1011;
                end
                2: begin
                    col_vals <= 4'b1101;
                end
                3: begin
                    col_vals <= 4'b1110;
                end
                default: begin
                end
            endcase
            polling_substate <= READING;
        end else if (polling_substate == READING) begin
            // check the rows
            case (row_vals)
                4'b1111: begin // Don't do anything
                end
                4'b0111: begin // row 0
                    key_num_pressed <= {2'b00, polling_state};
                    key_invalid <= key_invalid | key_pressed;
                    key_pressed <= 1;
                end
                4'b1011: begin // row 1
                    key_num_pressed <= {2'b01, polling_state};
                    key_invalid <= key_invalid | key_pressed;
                    key_pressed <= 1;
                end
                4'b1101: begin // row 2
                    key_num_pressed <= {2'b10, polling_state};
                    key_invalid <= key_invalid | key_pressed;
                    key_pressed <= 1;
                end
                4'b1110: begin // row 3
                    key_num_pressed <= {2'b11, polling_state};
                    key_invalid <= key_invalid | key_pressed;
                    key_pressed <= 1;
                end
                default: begin // 2 or more keys pressed (invalid)
                    key_invalid <= 1;
                end
            endcase

            if (polling_state < 3) begin
                polling_state <= polling_state + 1;
            end else begin
                polling_state <= 0;
            end
            polling_substate <= SETTING;
        end
  end



endmodule // input

`default_nettype wire
