`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Main processor module.
module chip8_processor(
    input wire clk_in,
    input wire rst_in,

    // determines when instructions are actually executed
    input wire chip8_clk_in,

    // whether or not to run stuff
    input wire active_in,
    // for delay and sound timer
    input wire timer_decr_in,

    // different input states
    input wire [3:0] any_key_in,
    input wire valid_key_in,
    input wire req_key_state_in,

    // receive instruction/data from memory
    input wire mem_valid_in,
    input wire [1:0] mem_in,

    // for asking input module for key
    output logic [4:0] req_key_out,

    // fetch instruction/data from memory
    output logic [11:0] mem_addr_out,

    // sprite drawing info
    output logic [11:0] sprite_addr_out,
    output logic [10:0] sprite_pos_out
  );

  // registers
  logic [8:0] vregs [16]; // registers V0 through V15/VF
  logic [15:0] ireg; // register I
  logic [7:0] delay_timer;
  logic [7:0] sound_timer;
  logic [15:0] pc; // program counter
  logic [15:0] sp; // stack pointer
  logic [15:0] stack [16]; // TODO: check if this is distinct from main memory

  always_ff @(posedge clk_in)begin
    // main logic
    if (rst_in)begin
    end else if (active_in)begin
      // TODO: main state machine goes here. states are as follows:
      // - idle (wait until chip8_clk_in)
      // - fetch (get instruction from memory)
      // - decode (do parsing here? maybe unnecessary)
      // - execute (massive switch statement for each instruction,
      //     i think variable length execution is fine because most of the
      //     time will be spent in idle anyways)
    end

    // handle timers independently
  end

endmodule // processor

`default_nettype wire
