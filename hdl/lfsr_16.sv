`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module lfsr_16 ( input wire clk_in, input wire rst_in,
                    input wire [15:0] seed_in,
                    output logic [15:0] q_out);
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      q_out <= seed_in;
    end else begin
      for (int i = 0; i < 16; i=i+1) begin
        if (i == 15 || i == 2) begin
          q_out[i] <= q_out[15] ^ q_out[i-1];
        end else if (i == 0) begin
          q_out[0] <= q_out[15];
        end else begin
          q_out[i] <= q_out[i-1];
        end
      end
    end
  end
endmodule

`default_nettype wire
