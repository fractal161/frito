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

    input wire [23:0] bg_color_in,
    input wire [23:0] fg_color_in,

    input wire [7:0] hdmi_data_in,

    // configuration
    input wire grid_in,

    // value of pixel requested for hdmi display
    // (colors can be inferred in top_level)
    output logic [15:0] hdmi_addr_out,
    output logic [7:0] hdmi_red_out,
    output logic [7:0] hdmi_green_out,
    output logic [7:0] hdmi_blue_out
  );

  logic [2:0] left_offset;
  logic [2:0] left_offset_piped;

  logic [10:0] x;
  logic [10:0] x_piped;

  logic [9:0] y;
  logic [9:0] y_piped;

  pipeline #(.WIDTH(3), .DEPTH(2)) left_offset_pipe(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .val_in(left_offset),
      .val_out(left_offset_piped)
    );

  pipeline #(.WIDTH(11), .DEPTH(2)) x_pipe(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .val_in(x),
      .val_out(x_piped)
    );

  pipeline #(.WIDTH(10), .DEPTH(2)) y_pipe(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .val_in(y),
      .val_out(y_piped)
    );

  always_comb begin
  end

  always_ff @(posedge clk_in)begin
    // TODO: customize
    left_offset <= hcount_in[6:4];
    hdmi_addr_out <= {
      8'b00000000,
      5'((vcount_in-104) >> 4),
      3'((hcount_in-128) >> 7)
    };
    x <= hcount_in - 128;
    y <= vcount_in - 104;
  end

  always_comb begin
    // right/bottom of grid
    if (grid_in && ((x_piped == 16*64 && y_piped <= 16*32)
      || (x_piped <= 16*64 && y_piped == 16*32))
    )begin
      hdmi_red_out = 8'h40;
      hdmi_green_out = 8'h40;
      hdmi_blue_out = 8'h40;
    end else if (x_piped >= 16*64 || y_piped >= 16*32)begin
      hdmi_red_out = 0;
      hdmi_green_out = 0;
      hdmi_blue_out = 0;
    end else begin
      if(!hdmi_data_in[7 - left_offset_piped])begin
        hdmi_red_out = bg_color_in[23:16];
        hdmi_green_out = bg_color_in[15:8];
        hdmi_blue_out = bg_color_in[7:0];
      end else begin
        hdmi_red_out = fg_color_in[23:16];
        hdmi_green_out = fg_color_in[15:8];
        hdmi_blue_out = fg_color_in[7:0];
      end
      if (grid_in && (x_piped[3:0] == 0 || y_piped[3:0] == 0))begin
        hdmi_red_out ^= 8'h40;
        hdmi_green_out ^= 8'h40;
        hdmi_blue_out ^= 8'h40;
      end
    end
  end

endmodule
`default_nettype wire
