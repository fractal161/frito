`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// determines what pixel to send to the hdmi unit
// base goal: handle one chip8
// stretch: handle many chip8s
module video_multiplexer(
    input wire clk_in,
    input wire rst_in,

    // hdmi pixel being requested
    input wire hcount_in,
    input wire vcount_in,

    // value of requested pixel from chip8_video
    input wire chip8_pixel_in,

    // value of pixel requested for hdmi display
    // (colors can be inferred in top_level)
    output logic hdmi_pixel_out,

    // requested pixel location from chip8_video
    output logic [5:0] chip8_x_out,
    output logic [4:0] chip8_y_out
  );

endmodule
`default_nettype wire
