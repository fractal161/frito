`timescale 1ns / 1ps
`default_nettype none

module pipeline #(
    parameter WIDTH = 1,
    parameter DEPTH = 1
) (
    input wire clk_in,
    input wire rst_in,
    input wire [WIDTH-1:0] val_in,
    output logic [WIDTH-1:0] val_out
);
  logic [WIDTH-1:0] pipe[DEPTH-1:0];
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      for (int i = 0; i < DEPTH; i = i + 1) begin
        pipe[i] <= 0;
      end
    end else begin
      for (int i = 0; i < DEPTH; i = i + 1) begin
        if (i == 0) begin
          pipe[i] <= val_in;
        end else begin
          pipe[i] <= pipe[i-1];
        end
      end
    end
  end
  assign val_out = pipe[DEPTH-1];
endmodule

// literally just copy-pasted the module from the lecture notes lmao, it does
// the job
`default_nettype wire
