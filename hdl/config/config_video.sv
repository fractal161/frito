`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// configuration
// assumes a tile is 32x32, so the screen fits around 23x40
module config_video(
    input wire clk_in,
    input wire rst_in,

    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,

    input wire [7:0] tile_row_in,
    input wire [7:0] buf_read_data_in,

    input wire [3:0] ptr_index_in,
    // TODO: inputs defining current menu state (i.e. what to show)
    output logic [23:0] pixel_out,

    output logic [11:0] tile_addr_out,
    output logic [9:0] buf_read_addr_out
  );

  localparam int PIPE_DEPTH = 3;

  logic [2:0] tile_row_index;

  logic [10:0] hcount_pipe[PIPE_DEPTH-1:0];
  logic [9:0] vcount_pipe[PIPE_DEPTH-1:0];

  // pipelines for hcount and vcount
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      for (int i = 0; i < PIPE_DEPTH; i = i + 1) begin
        hcount_pipe[i] <= 0;
        vcount_pipe[i] <= 0;
      end
    end else begin
      for (int i = 0; i < PIPE_DEPTH; i = i + 1) begin
        if (i == 0) begin
          hcount_pipe[i] <= hcount_in;
          vcount_pipe[i] <= vcount_in;
        end else begin
          hcount_pipe[i] <= hcount_pipe[i-1];
          vcount_pipe[i] <= vcount_pipe[i-1];
        end
      end
    end
  end

  localparam [63:0] cursor = 64'h00103070F0703010;
  logic in_cursor;

  // check if hcount is inside cursor
  always_comb begin
    //in_cursor = 0;
    if (ptr_index_in < 8)begin
      if (
        hcount_pipe[2][10:5] == 6'h1
        && vcount_pipe[2][9:5] == 5'(3+(ptr_index_in << 1))
      )begin
        //in_cursor = 1;
        in_cursor = cursor[(6'(vcount_pipe[2][4:2])<<3)+6'(hcount_pipe[2][4:2])];
      end else begin
        in_cursor = 0;
      end
    end else if (ptr_index_in < 12)begin
      if (
        hcount_pipe[2][10:5] == 6'd21
        && vcount_pipe[2][9:5] == 5'(3+((ptr_index_in-8) << 1))
      )begin
        //in_cursor = 1;
        in_cursor = cursor[(6'(vcount_pipe[2][4:2]<<3))+6'(hcount_pipe[2][4:2])];
      end else begin
        in_cursor = 0;
      end
    end
  end

  always_comb begin
    // 2048 + 40 * (vcount_in >> 5) + (hcount_in >> 5)
    buf_read_addr_out = (vcount_in[9:5] << 5)
        + (vcount_in[9:5] << 3)
        + hcount_in[10:5];
    tile_row_index = vcount_pipe[0][4:2]; // TODO: check pipeline
    tile_addr_out = (buf_read_data_in << 3) + tile_row_index;
  end

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      pixel_out <= 24'h000000;
    end else begin
      // fetch
      if (hcount_pipe[2][4:0] == 0 || vcount_pipe[2][4:0] == 0)begin
        pixel_out <= 24'h444444;
      end else if(in_cursor)begin
        pixel_out <= 24'hFFFFFF;
      end else if (tile_row_in[7-hcount_pipe[2][4:2]])begin
        pixel_out <= 24'hFFFFFF;
      end else begin
        pixel_out <= 24'h000000;
      end
    end
  end

endmodule

`default_nettype wire
