`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// determines what pixel to send to the hdmi unit
// base goal: handle one chip8
// stretch: handle many chip8s
module video_multiplexer(
    input wire clk_in,
    input wire rst_in,

    // hdmi pixel being requested
    input wire hcount_in, // [0,1280)
    input wire vcount_in, // [0,720)

    input wire [7:0] hdmi_data_in,

    // value of pixel requested for hdmi display
    // (colors can be inferred in top_level)
    output logic [15:0] hdmi_addr_out,
    output logic hdmi_pixel_out,
  );
  
  logic [5:0] chip8_x_out;
  logic [4:0] chip8_y_out;
  logic [2:0] chip8_x_byte;
  logic [2:0] left_offset;

  always_comb begin
      // TODO: make this more customizable
      chip8_x_out = (hcount_in >> 4); // floor divide by 16
      chip8_y_out = (vcount_in >> 4);

      chip8_x_byte = (chip8_x_out >> 3);
      left_offset = chip8_x_out[2:0];

      // read from VRAM
      hdmi_addr_out = ({8'b00000000, chip8_y_out, chip8_x_byte}); // takes 2 cycles to show up in hdmi_data_in
      hdmi_pixel_out = (hdmi_data_in >> left_offset); // will take the LSB by default
  end

endmodule
`default_nettype wire
