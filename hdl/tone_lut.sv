`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

//10 bit tone lookup table
module tone_lut (input wire [9:0] tone, output logic [31:0] phase_out);
  always_comb begin
    case(tone)
      10'd220: phase_out = ((32'b1000_0000_0000_0000_0000_0000_0000_0000>>1)/75)*22;
      10'd375: phase_out = 32'b1000_0000_0000_0000_0000_0000_0000_0000>>2;
      10'd440: phase_out = ((32'b1000_0000_0000_0000_0000_0000_0000_0000>>1)/75)*44;
      10'd750: phase_out = 32'b1000_0000_0000_0000_0000_0000_0000_0000>>1;
    endcase
  end
endmodule

`default_nettype wire