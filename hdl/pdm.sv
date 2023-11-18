`timescale 1ns / 1ps
`default_nettype none


module pdm(
            input wire clk_in,
            input wire rst_in,
            input wire signed [7:0] level_in,
            input wire tick_in,
            output logic pdm_out
  );

	logic signed [8:0] sum;

  	always_ff @(posedge clk_in) begin
		if (rst_in) begin
			sum <= 0;
		end else if (tick_in) begin
			if (sum >= 0) begin
				sum <= sum + level_in - 127;
			end else begin
				sum <= sum + level_in + 128;
			end
		end    
  	end

	assign pdm_out = ~sum[8];

endmodule


`default_nettype wire
