`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

// memory module
// for simplicity we use two brams: one for tiles/menu names and one for the
// buffer
module config_memory(
    input wire clk_in,
    input wire rst_in,

    input wire [11:0] tile_addr_in,
    input wire [11:0] menu_addr_in,

    // update video buffer with new value
    input wire buf_write_valid_in,
    input wire [9:0] buf_write_addr_in,
    input wire [7:0] buf_write_data_in,

    input wire [9:0] buf_read_addr_in,

    output logic [7:0] tile_row_out,
    output logic [7:0] menu_tile_out,
    output logic [7:0] buf_tile_out
  );

  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(8),
      .RAM_DEPTH(2048),
      .INIT_FILE(`FPATH(cfg_data.mem))
    ) tile_and_menu_mem (
      // fetch tile row
      .addra(tile_addr_in),
      .clka(clk_in),
      .wea(1'b0), // write-enable
      .dina(8'b0), // data_in
      .ena(1'b1), // set to 0 to save power
      .regcea(1'b1),
      .rsta(rst_in),
      .douta(tile_row_out),

      // fetch menu row tile
      .addrb(menu_addr_in),
      .clkb(clk_in),
      .web(1'b0), // write-enable (hdmi should never write to ram)
      .dinb(8'b0), // read only, so unnecessary
      .enb(1'b1), // set to 0 to save power
      .regceb(1'b1),
      .rstb(rst_in),
      .doutb(menu_tile_out)
    );

  // fetches tile type, then uses that to fetch the row of interest
  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(8),
      .RAM_DEPTH(40*23),
      .INIT_FILE(`FPATH(cfg_buffer.mem))
    ) buffer_mem (
      // write tile index
      .addra(buf_write_addr_in),
      .clka(clk_in),
      .wea(buf_write_valid_in), // write-enable
      .dina(buf_write_data_in), // data_in
      .ena(1'b1), // set to 0 to save power
      .regcea(1'b1),
      .rsta(rst_in),
      //.douta(),

      // fetch tile index
      .addrb(buf_read_addr_in),
      .clkb(clk_in),
      .web(1'b0), // write-enable
      .dinb(8'b0), // read only, so unnecessary
      .enb(1'b1), // set to 0 to save power
      .regceb(1'b1),
      .rstb(rst_in),
      .doutb(buf_tile_out)
    );
endmodule

`default_nettype wire
