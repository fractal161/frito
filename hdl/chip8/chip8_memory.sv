`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Coordinates access to the memory between the processor and video buffer.
module chip8_memory(
    input wire clk_in,
    input wire rst_in,

    // indicates whether to copy a program from the library
    input wire flash_in
    // TODO: rest of parameters
  );

  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(8),
      .RAM_DEPTH(4096)
    ) memory (
      // TODO: assign properly
      // processor fetch
      .addra(),
      .clka(clk_in),
      .wea(),
      .dina(),
      .ena(),
      .regcea(),
      .rsta(rst_in),
      .douta(),

      // video fetch
      .addrb(),
      .clkb(clk_in),
      .web(),
      .dinb(),
      .enb(),
      .regceb(),
      .rstb(rst_in),
      .doutb(),

    );

  always_ff @(posedge clk_in)begin
  end

endmodule // top_level

`default_nettype wire

