`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

//Sine Wave Generator
module triangle_generator (
  input wire clk_in,
  input wire rst_in, //clock and reset
  input wire step_in, //trigger a phase step (rate at which you run sine generator)
  input wire [9:0] tone_in,
  output logic signed [7:0] amp_out); //output phase in 2's complement

  // parameter PHASE_INCR = 32'b1000_0000_0000_0000_0000_0000_0000_0000>>3; //1/16th of 12 khz is 750 Hz
  logic [31:0] phase;
  logic signed [7:0] amp;
  logic signed [7:0] amp_pre;
  logic [31:0] phase_incr;
  assign amp_pre = ({~amp[7],amp[6:0]}); //2's comp output (if not scaling)
  assign amp_out = amp_pre; //decrease volume so it isn't too loud!
  triangle_lut lut_3(.clk_in(clk_in), .phase_in(phase[31:26]), .amp_out(amp));
  tone_lut tlut_3(.tone(tone_in), .phase_out(phase_incr));

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      phase <= 32'b0;
    end else if (step_in)begin
      phase <= phase+phase_incr;
    end
  end
endmodule

//6bit triangle lookup, 8bit depth
module triangle_lut(input wire [5:0] phase_in, input wire clk_in, output logic[7:0] amp_out);
  always_ff @(posedge clk_in)begin
    case(phase_in)
        6'd0: amp_out<=8'd128;
        6'd1: amp_out<=8'd136;
        6'd2: amp_out<=8'd144;
        6'd3: amp_out<=8'd152;
        6'd4: amp_out<=8'd160;
        6'd5: amp_out<=8'd168;
        6'd6: amp_out<=8'd176;
        6'd7: amp_out<=8'd184;
        6'd8: amp_out<=8'd192;
        6'd9: amp_out<=8'd200;
        6'd10: amp_out<=8'd208;
        6'd11: amp_out<=8'd216;
        6'd12: amp_out<=8'd224;
        6'd13: amp_out<=8'd232;
        6'd14: amp_out<=8'd240;
        6'd15: amp_out<=8'd248;
        6'd16: amp_out<=8'd248;
        6'd17: amp_out<=8'd240;
        6'd18: amp_out<=8'd232;
        6'd19: amp_out<=8'd224;
        6'd20: amp_out<=8'd216;
        6'd21: amp_out<=8'd208;
        6'd22: amp_out<=8'd200;
        6'd23: amp_out<=8'd192;
        6'd24: amp_out<=8'd184;
        6'd25: amp_out<=8'd176;
        6'd26: amp_out<=8'd168;
        6'd27: amp_out<=8'd160;
        6'd28: amp_out<=8'd152;
        6'd29: amp_out<=8'd144;
        6'd30: amp_out<=8'd136;
        6'd31: amp_out<=8'd128;
        6'd32: amp_out<=8'd120;
        6'd33: amp_out<=8'd112;
        6'd34: amp_out<=8'd104;
        6'd35: amp_out<=8'd96;
        6'd36: amp_out<=8'd88;
        6'd37: amp_out<=8'd80;
        6'd38: amp_out<=8'd72;
        6'd39: amp_out<=8'd64;
        6'd40: amp_out<=8'd56;
        6'd41: amp_out<=8'd48;
        6'd42: amp_out<=8'd40;
        6'd43: amp_out<=8'd32;
        6'd44: amp_out<=8'd24;
        6'd45: amp_out<=8'd16;
        6'd46: amp_out<=8'd8;
        6'd47: amp_out<=8'd0;
        6'd48: amp_out<=8'd8;
        6'd49: amp_out<=8'd16;
        6'd50: amp_out<=8'd24;
        6'd51: amp_out<=8'd32;
        6'd52: amp_out<=8'd40;
        6'd53: amp_out<=8'd48;
        6'd54: amp_out<=8'd56;
        6'd55: amp_out<=8'd64;
        6'd56: amp_out<=8'd72;
        6'd57: amp_out<=8'd80;
        6'd58: amp_out<=8'd88;
        6'd59: amp_out<=8'd96;
        6'd60: amp_out<=8'd104;
        6'd61: amp_out<=8'd112;
        6'd62: amp_out<=8'd120;
        6'd63: amp_out<=8'd128;
    endcase
  end
endmodule

`default_nettype wire
