`timescale 1ns / 1ps
`default_nettype none

module video_sig_gen
#(
  parameter int ACTIVE_H_PIXELS = 1280,
  parameter int H_FRONT_PORCH = 110,
  parameter int H_SYNC_WIDTH = 40,
  parameter int H_BACK_PORCH = 220,
  parameter int ACTIVE_LINES = 720,
  parameter int V_FRONT_PORCH = 5,
  parameter int V_SYNC_WIDTH = 5,
  parameter int V_BACK_PORCH = 20)
(
  input wire clk_pixel_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out,
  output logic hs_out,
  output logic ad_out,
  output logic nf_out,
  output logic [5:0] fc_out
);

  localparam int TOTAL_PIXELS = ACTIVE_H_PIXELS
    + H_FRONT_PORCH
    + H_SYNC_WIDTH
    + H_BACK_PORCH;
  localparam int TOTAL_LINES = ACTIVE_LINES
    + V_FRONT_PORCH
    + V_SYNC_WIDTH
    + V_BACK_PORCH;

  // current state
  logic [$clog2(TOTAL_PIXELS)-1:0] hcount;
  logic [$clog2(TOTAL_LINES)-1:0] vcount;
  logic [5:0] fc;

  always_ff @(posedge clk_pixel_in) begin
    if (rst_in) begin
      hcount <= 0;
      vcount <= 0;

      hcount_out <= 0;
      vcount_out <= 0;
      ad_out <= 0;
      hs_out <= 0;
      vs_out <= 0;
      nf_out <= 0;
      fc <= 0;
    end else begin
      // set each signal depending on current state
      ad_out <= (hcount < ACTIVE_H_PIXELS && vcount < ACTIVE_LINES) ? 1 : 0;
      hs_out <= (
        ACTIVE_H_PIXELS + H_FRONT_PORCH <= hcount
        && hcount < ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH
      ) ? 1 : 0;
      vs_out <= (
        ACTIVE_LINES + V_FRONT_PORCH <= vcount
        && vcount < ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH
      ) ? 1 : 0;
      if (hcount == ACTIVE_H_PIXELS && vcount == ACTIVE_LINES) begin
        nf_out <= 1;
        fc <= (fc == 59) ? 0 : fc + 1;
      end else begin
        nf_out <= 0;
      end

      hcount_out <= hcount;
      vcount_out <= vcount;

      // increment state
      if (hcount == TOTAL_PIXELS - 1) begin
        hcount <= 0;
        vcount <= (vcount == TOTAL_LINES - 1) ? 0 : vcount + 1;
      end else begin
        hcount <= hcount + 1;
      end

    end
  end
  assign fc_out = fc;

endmodule

`default_nettype wire
