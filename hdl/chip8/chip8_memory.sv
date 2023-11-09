`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

// Coordinates access to the memory between the processor and video buffer.
// We reserve one port for the multiplexer so it always has consistent access
// to the value of a pixel. Thus, everything else competes for access to the
// other port. Currently, this includes the processor, video, and flash.
// HOWEVER, most of these things will probably block each other, so we can
// probably get away with a really naive policy for determining what goes

// Internally, memory is stored in a BRAM of width 8

// TODO: proper reset handling
// TODO: optimize this later. For example, only one of proc_ram, proc_reg, and
// proc_stk will ever be requested at a time, so can probably optimize cycles
// here
module chip8_memory #(
    parameter int WIDTH = 8,
    parameter string FILE = `FPATH(ibm.mem)
) (
    input wire clk_in,
    input wire hdmi_clk_in,
    input wire rst_in,

    // indicates whether to copy a program from the library
    //input wire flash_in,
    //input wire [7:0] flash_data_in,

    // r/w to chip-8 ram/reg/stk (12 bits for ram, 5 for reg/stack)
    // order of regs: V0-VF, Ih/Il, PCh/PCl, SP, DT, ST
    input wire [11:0] proc_addr_in,
    input wire proc_we_in,
    input wire proc_valid_in,
    input wire [WIDTH-1:0] proc_data_in,
    input wire [$clog2(PROC_MEM_TYPE_COUNT)-1:0] proc_type_in,

    // r/w a byte from the video buffer (TODO: how to handle address??)
    input wire [15:0] video_addr_in,
    input wire video_we_in,
    input wire video_valid_in,
    input wire [WIDTH-1:0] video_data_in,
    input wire [0:0] video_type_in,

    input wire [11:0] debug_addr_in,
    input wire debug_we_in,
    input wire debug_valid_in,
    input wire [WIDTH-1:0] debug_data_in,
    input wire [$clog2(DEBUG_MEM_TYPE_COUNT)-1:0] debug_type_in,

    // flash rom (TODO: add)

    // get value for hdmi module
    input wire [15:0] hdmi_addr_in,

    // readies for each pattern
    output logic proc_ready_out,
    output logic proc_valid_out,
    //output logic flash_ready_out,

    // indicates when the result of a r/w to the first port is valid
    output logic video_ready_out,
    output logic video_valid_out,
    //output logic flash_valid_out,

    output logic debug_ready_out,
    output logic debug_valid_out,

    // actual data that's read
    output logic [WIDTH-1:0] data_out,

    // requested value of hdmi pixel
    output logic [WIDTH-1:0] hdmi_data_out
  );

  // computes total bytes
  localparam int RAM_DEPTH = 4096;
  localparam int VRAM_DEPTH = 64*32/8;
  localparam int REG_DEPTH = 16*1 // V0-VF
    + 1*2 // I
    + 1*2 // PC
    + 1*1 // SP
    + 2*1; // DT and ST
  localparam int STK_DEPTH = 16*2;
  localparam int DEPTH = RAM_DEPTH + VRAM_DEPTH + REG_DEPTH + STK_DEPTH;
  // TODO: add byte for hires status

  // types of access patterns that compete for the first port
  // each one has their own addressing strategy, so they're handled separately
  localparam int NONE = 0; // don't set anything to valid
  localparam int PROC = 1;
  localparam int VIDEO = 2; // video module setting a pixel (TODO: offsets)
  localparam int DEBUG = 3;
  //localparam int FLASH = 5;
  localparam int NUM_STATES = 4; // for looping counter

  logic [$clog2(NUM_STATES)-1:0] state; // continually cycles through all states

  logic [$clog2(NUM_STATES)-1:0] state_out;

  // parameters for first port
  logic [$clog2(DEPTH)-1:0] addr;
  logic we;
  logic [WIDTH-1:0] data_in;

  // parameters for second port
  logic [$clog2(DEPTH)-1:0] hdmi_addr;

  // output is the type of state (depth verified using tb)
  pipeline #(.WIDTH($clog2(NUM_STATES)), .DEPTH(1)) state_pipeline(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .val_in(state),
      .val_out(state_out)
    );

  // temp storage for various params
  logic [11:0] proc_addr;
  logic proc_we;
  logic [WIDTH-1:0] proc_data;
  logic [$clog2(PROC_MEM_TYPE_COUNT)-1:0] proc_type;

  logic [11:0] video_addr;
  logic video_we;
  logic [WIDTH-1:0] video_data;
  logic [1:0] video_type;

  logic [11:0] debug_addr;
  logic debug_we;
  logic [WIDTH-1:0] debug_data;
  logic [$clog2(DEBUG_MEM_TYPE_COUNT)-1:0] debug_type;

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      state <= NONE;
      proc_ready_out <= 1;
      proc_valid_out <= 0;

      video_ready_out <= 1;
      video_valid_out <= 0;

      debug_ready_out <= 1;
      debug_valid_out <= 0;

      addr <= 0;
      we <= 0;
      data_in <= 0;

    end else begin
      // figure out if request should be made (i.e. assign state)
      // first, check if we have a pending request to process
      // TODO: this design is tricky, think really really hard about it
      if (!proc_ready_out)begin
        we <= proc_we;
        data_in <= proc_data;
        case (proc_type)
          PROC_MEM_TYPE_RAM: addr <= proc_addr;
          PROC_MEM_TYPE_REG: addr <= RAM_DEPTH + VRAM_DEPTH + proc_addr;
          PROC_MEM_TYPE_STK: addr <= RAM_DEPTH + VRAM_DEPTH
            + REG_DEPTH + proc_addr;
          default: begin
            // TODO: error
          end
        endcase
        proc_ready_out <= 1;
      end else if (!video_ready_out)begin
        // TODO: casework
        we <= video_we;
        data_in <= video_data;
        addr <= RAM_DEPTH + video_addr;
        video_ready_out <= 1;
      end else if (!debug_ready_out)begin
        we <= debug_we;
        data_in <= debug_data;
        case (debug_type)
          DEBUG_MEM_TYPE_RAM: addr <= debug_addr;
          DEBUG_MEM_TYPE_VRAM: addr <= RAM_DEPTH + debug_addr;
          DEBUG_MEM_TYPE_REG: addr <= RAM_DEPTH + VRAM_DEPTH + debug_addr;
          DEBUG_MEM_TYPE_STK: addr <= RAM_DEPTH + VRAM_DEPTH
            + REG_DEPTH + debug_addr;
          default: begin
            // TODO: error
          end
        endcase
        debug_ready_out <= 1;
      end
      if (proc_ready_out && proc_valid_in)begin
        if (!video_ready_out)begin
          // in this case something's already been written to we/addr, so we
          // stash the inputs for now
          proc_we <= proc_we_in;
          proc_data <= proc_data_in;
          proc_addr <= proc_addr_in;
          proc_ready_out <= 0;
        end else begin
          // otherwise, we can write directly
          we <= proc_we_in;
          data_in <= proc_data_in;
          case (proc_type_in)
            PROC_MEM_TYPE_RAM: addr <= proc_addr_in;
            PROC_MEM_TYPE_REG: addr <= RAM_DEPTH + VRAM_DEPTH + proc_addr_in;
            PROC_MEM_TYPE_STK: addr <= RAM_DEPTH + VRAM_DEPTH
              + REG_DEPTH + proc_addr_in;
            default: begin
              // TODO: error
            end
          endcase
        end
      end
      if (video_ready_out && video_valid_in)begin
        if (!proc_ready_out || proc_valid_in)begin
          // stash
          video_we <= video_we_in;
          video_data <= video_data_in;
          video_addr <= video_addr_in;
          video_ready_out <= 0;
        end else begin
          we <= video_we_in;
          data_in <= video_data_in;
          addr <= RAM_DEPTH + video_addr_in;
        end
      end
      if (debug_ready_out && debug_valid_in)begin
        if (!proc_ready_out || proc_valid_in
          || !video_ready_out || video_valid_in
        )begin
          // stash
          debug_we <= debug_we_in;
          debug_data <= debug_data_in;
          debug_addr <= debug_addr_in;
          debug_ready_out <= 0;
        end else begin
          we <= debug_we_in;
          data_in <= debug_data_in;
          case (debug_type_in)
            DEBUG_MEM_TYPE_RAM: addr <= debug_addr_in;
            DEBUG_MEM_TYPE_VRAM: addr <= RAM_DEPTH + debug_addr_in;
            DEBUG_MEM_TYPE_REG: addr <= RAM_DEPTH + VRAM_DEPTH + debug_addr_in;
            DEBUG_MEM_TYPE_STK: addr <= RAM_DEPTH + VRAM_DEPTH
              + REG_DEPTH + debug_addr_in;
            default: begin
              // TODO: error
            end
          endcase
        end
      end
      // determine what to send out
      proc_valid_out <= (state_out == PROC);
      video_valid_out <= (state_out == VIDEO);
      debug_valid_out <= (state_out == DEBUG);

      // massive conditional for state
      if (!proc_ready_out
        || (video_ready_out && debug_ready_out && proc_valid_in)
      )begin
        state <= PROC;
      end else if (!video_ready_out
        || (debug_ready_out && !proc_valid_in && video_valid_in)
      )begin
        state <= VIDEO;
      end else if (!debug_ready_out
        || (!proc_valid_in && !video_valid_in && debug_valid_in)
      )begin
        state <= DEBUG;
      end else begin
        state <= NONE;
      end
    end
  end

  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(WIDTH),
      .RAM_DEPTH(DEPTH),
      .INIT_FILE(FILE)
    ) memory (
      .addra(addr),
      .clka(clk_in),
      .wea(we), // write-enable
      .dina(data_in), // data_in
      .ena(1'b1), // set to 0 to save power
      .regcea(1'b1),
      .rsta(rst_in),
      .douta(data_out),

      // hdmi fetch
      .addrb(),
      .clkb(hdmi_clk_in),
      .web(1'b0), // write-enable (hdmi should never write to ram)
      .dinb(8'b0), // read only, so unnecessary
      .enb(1'b1), // set to 0 to save power
      .regceb(1'b1),
      .rstb(rst_in),
      .doutb(hdmi_data_out)
    );

endmodule // memory

`default_nettype wire
