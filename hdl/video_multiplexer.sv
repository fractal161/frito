`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// determines what pixel to send to the hdmi unit
// base goal: handle one chip8
// stretch: handle many chip8s
module video_multiplexer(
    input wire clk_in,
    input wire rst_in,

    // hdmi pixel being requested
    input wire [10:0] hcount_in, // [0,1280)
    input wire [9:0] vcount_in, // [0,720)

    input wire [7:0] hdmi_data_in,

    // value of pixel requested for hdmi display
    // (colors can be inferred in top_level)
    output logic [15:0] hdmi_addr_out,
    output logic hdmi_pixel_out
  );

  logic [5:0] chip8_x_out;
  logic [4:0] chip8_y_out;
  logic [2:0] chip8_x_byte;
  logic [2:0] chip8_x_byte_piped;
  logic [2:0] left_offset;
  logic [2:0] left_offset_piped;

  pipeline #(.WIDTH(3), .DEPTH(2)) left_offset_pipe(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .val_in(left_offset),
      .val_out(left_offset_piped)
    );

  always_ff @(posedge clk_in)begin
    // TODO: customize
    left_offset <= hcount_in[6:4];
    hdmi_addr_out <= ({8'b00000000, vcount_in[8:4], hcount_in[9:7]}); // 2 cycle latency
    if (hcount_in > 16*64 || vcount_in > 16*32) begin
      hdmi_pixel_out <= 0;
    end else begin
      hdmi_pixel_out <= (hdmi_data_in >> (7 - left_offset_piped)); // will take the LSB by default
    end
  end

endmodule
`default_nettype wire
