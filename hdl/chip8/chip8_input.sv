`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Converts raw signal from keypad into input
// https://www.labcenter.com/blog/sim-matrix-keypad/#:~:text=Reading%20a%20Matrix%20Keypad,the%20button%20is%20not%20pressed
module chip8_input(
    input wire clk_in,
    input wire rst_in,
    input wire [3:0] row_vals,
    output logic [3:0] col_vals,
    output logic [15:0] key_pressed_out
  );

  // Strategy: pull individual columns to 0, then check which rows are 0
  // Currently takes 8 cycles to poll the keypad

  logic [1:0] polling_state; // 0 to 3

  logic polling_substate;
  localparam SETTING = 0;
  localparam READING = 1;

  logic [15:0] key_pressed_vals;
  logic [15:0] full_key_state;

  always_comb begin
    key_pressed_out[0] = full_key_state[13];
    key_pressed_out[1] = full_key_state[0];
    key_pressed_out[2] = full_key_state[1];
    key_pressed_out[3] = full_key_state[2];
    key_pressed_out[4] = full_key_state[4];
    key_pressed_out[5] = full_key_state[5];
    key_pressed_out[6] = full_key_state[6];
    key_pressed_out[7] = full_key_state[8];
    key_pressed_out[8] = full_key_state[9];
    key_pressed_out[9] = full_key_state[10];
    key_pressed_out[10] = full_key_state[12];
    key_pressed_out[11] = full_key_state[14];
    key_pressed_out[12] = full_key_state[3];
    key_pressed_out[13] = full_key_state[7];
    key_pressed_out[14] = full_key_state[11];
    key_pressed_out[15] = full_key_state[15];
  end

  always_ff @(posedge clk_in) begin
        if (rst_in) begin
           polling_state <= 0;
           polling_substate <= SETTING;
           key_pressed_vals <= 0;
        end else if (polling_substate == SETTING) begin
            // pull a column to 0
            case (polling_state)
                0: begin
                    // Output is from the previous polling cycle
                    full_key_state <= key_pressed_vals;
                    key_pressed_vals <= 0;

                    col_vals <= 4'b1110;
                end
                1: begin
                    col_vals <= 4'b1101;
                end
                2: begin
                    col_vals <= 4'b1011;
                end
                3: begin
                    col_vals <= 4'b0111;
                end
                default: begin
                end
            endcase
            polling_substate <= READING;
        end else if (polling_substate == READING) begin
            // check which rows have been pulled down
            key_pressed_vals[{2'b00, polling_state}] <= ~row_vals[2'b00];
            key_pressed_vals[{2'b01, polling_state}] <= ~row_vals[2'b01];
            key_pressed_vals[{2'b10, polling_state}] <= ~row_vals[2'b10];
            key_pressed_vals[{2'b11, polling_state}] <= ~row_vals[2'b11];

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
