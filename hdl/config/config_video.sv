`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

// configuration
// assumes a tile is 32x32, so the screen fits around 23x40
module config_video(
    input wire clk_in,
    input wire rst_in,

    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,

    input wire [10:0] ptr_x_in,
    input wire [9:0] ptr_y_in,
    // TODO: inputs defining current menu state (i.e. what to show)
    output logic [23:0] pixel_out
  );
  localparam int WIDTH = 8;
  localparam int DEPTH = 8*256 + 40*23;

  localparam int PIPE_DEPTH = 3;

  logic [11:0] addr;
  logic [10:0] tile_addr;
  logic [2:0] tile_row_index;

  logic [7:0] tile_type;
  logic [7:0] tile_row;

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

  always_comb begin
    // 2048 + 40 * (vcount_in >> 5) + (hcount_in >> 5)
    addr = 2048
        + (vcount_in[9:5] << 5)
        + (vcount_in[9:5] << 3)
        + hcount_in[10:5];
    tile_row_index = vcount_pipe[0][4:2]; // TODO: check pipeline
    tile_addr = (tile_type << 3) + tile_row_index;
  end

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      pixel_out <= 24'h000000;
    end else begin
      // fetch
      if (hcount_pipe[2][4:0] == 0 || vcount_pipe[2][4:0] == 0)begin
        pixel_out <= 24'h404040;
      end else if (tile_row[7-hcount_pipe[2][4:2]])begin // TODO: check pipeline
        pixel_out <= 24'hFFFFFF;
      end else begin
        pixel_out <= 24'h000000;
      end
    end
  end

  // fetches tile type, then uses that to fetch the row of interest
  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(WIDTH),
      .RAM_DEPTH(DEPTH),
      .INIT_FILE(`FPATH(cfg.mem))
    ) memory (
      .addra(addr), // TODO: correct addr
      .clka(clk_in),
      .wea(1'b0), // write-enable
      .dina(8'b0), // data_in
      .ena(1'b1), // set to 0 to save power
      .regcea(1'b1),
      .rsta(rst_in),
      .douta(tile_type),

      // hdmi fetch
      .addrb(tile_addr), // TODO: correct addr
      .clkb(clk_in),
      .web(1'b0), // write-enable (hdmi should never write to ram)
      .dinb(8'b0), // read only, so unnecessary
      .enb(1'b1), // set to 0 to save power
      .regceb(1'b1),
      .rstb(rst_in),
      .doutb(tile_row)
    );
endmodule

`default_nettype wire
