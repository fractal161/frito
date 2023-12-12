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
    input wire [3:0] rows_in,
    input wire [3:0] cols_in,

    input wire grid_in,

    // value of pixel requested for hdmi display
    // (colors can be inferred in top_level)
    output logic [15:0] hdmi_addr_out,
    output logic [7:0] hdmi_red_out,
    output logic [7:0] hdmi_green_out,
    output logic [7:0] hdmi_blue_out,

    output logic [5:0] chip_index_out
  );

  logic [2:0] left_offset;
  logic [2:0] left_offset_piped;

  logic [10:0] x_tmp;
  logic [10:0] x;
  logic [10:0] x_piped;

  logic [9:0] y_tmp;
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

  logic [2:0] row_depth; // 2^pixel_depth is the width
  logic [2:0] col_depth; // 2^pixel_depth is the width
  logic [2:0] pixel_depth; // 2^pixel_depth is the width
  logic [10:0] screen_width;
  logic [9:0] screen_height;

  logic [10:0] hspace;
  logic [9:0] vspace;

  // TODO: maybe pipeline this?
  always_comb begin
    case(rows_in)
      4'h1: row_depth = 4;
      4'h2: row_depth = 3;
      4'h3: row_depth = 2;
      4'h4: row_depth = 1;
      4'h5: row_depth = 1;
      4'h6: row_depth = 1;
      4'h7: row_depth = 1;
      4'h8: row_depth = 1;
      default: begin
      end
    endcase
    case(cols_in)
      4'h1: col_depth = 4;
      4'h2: col_depth = 3;
      4'h3: col_depth = 2;
      4'h4: col_depth = 1;
      4'h5: col_depth = 1;
      4'h6: col_depth = 1;
      4'h7: col_depth = 1;
      4'h8: col_depth = 1;
      default: begin
      end
    endcase
    pixel_depth = (row_depth < col_depth) ? row_depth : col_depth;

    screen_width = 1 << (6+pixel_depth);
    screen_height = 1 << (5+pixel_depth);
    hspace = 11'd1280 - (11'(cols_in) << (6+pixel_depth));
    vspace = 10'd720 - (10'(rows_in) << (5+pixel_depth));
  end

  logic [10:0] hstep;
  logic [3:0] hoff; // used to fine-tune a bit more
  logic [9:0] vstep;
  logic [3:0] voff;

  divider compute_hstep(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .dividend_in(hspace),
      .divisor_in(cols_in+1),
      .data_valid_in(1'b1),

      .quotient_out(hstep),
      .remainder_out(hoff)
    );

  divider compute_vstep(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .dividend_in(vspace),
      .divisor_in(rows_in+1),
      .data_valid_in(1'b1),

      .quotient_out(vstep),
      .remainder_out(voff)
    );

  // compute spacing for both horizontal and vertical
  logic [10:0] htally;
  logic [9:0] vtally;

  always_comb begin
    x_tmp = screen_width-1-htally+hcount_in;
    y_tmp = screen_height-1-vtally+vcount_in;
  end

  always_ff @(posedge clk_in)begin
    if (hcount_in == 0)begin
      htally <= hstep + screen_width + (hoff >> 1);

      if (vcount_in == 0)begin
        chip_index_out <= 0;
        vtally <= vstep + screen_height + (voff >> 1);
      end else if (vcount_in == vtally+vstep+2)begin
        if (10'd720-vcount_in > screen_height)begin
          chip_index_out <= chip_index_out + 1;
          vtally <= vtally + vstep + screen_height;
        end
      end else begin
        chip_index_out <= chip_index_out - cols_in + 1;
      end
    end else if (hcount_in == htally+1+2)begin
      if (11'd1280-hcount_in > screen_width)begin
        chip_index_out <= chip_index_out + 1;
        htally <= htally + hstep + screen_width;
      end
    end
    x <= x_tmp;
    y <= y_tmp;

    hdmi_addr_out <= {
      8'h00,
      5'(y_tmp >> pixel_depth),
      3'(x_tmp >> (3+pixel_depth))
    };
    left_offset <= x_tmp >> pixel_depth;
  end

  always_comb begin
    // right/bottom of grid
    if (x_piped > screen_width || y_piped > screen_height)begin
      if (
        (x_piped == 11'h7FF && y_piped <= screen_height)
        || (y_piped == 10'h3FF && x_piped <= screen_width)
      )begin
        hdmi_red_out = 8'h40;
        hdmi_green_out = 8'h40;
        hdmi_blue_out = 8'h40;
      end else begin
        hdmi_red_out = 0;
        hdmi_green_out = 0;
        hdmi_blue_out = 0;
      end
    end else if (x_piped == screen_width || y_piped == screen_height)begin
      // draw border
      hdmi_red_out = 8'h40;
      hdmi_green_out = 8'h40;
      hdmi_blue_out = 8'h40;
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
      if (grid_in && (
        (x_piped & ((11'h1 << pixel_depth)-1)) == 0
        || (y_piped & ((10'h1 << pixel_depth)-1)) == 0
      ))begin
        hdmi_red_out ^= 8'h40;
        hdmi_green_out ^= 8'h40;
        hdmi_blue_out ^= 8'h40;
      end
    end
  end

endmodule
`default_nettype wire
