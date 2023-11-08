`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Coordinates access to the memory between the processor and video buffer.
// We reserve one port for the multiplexer so it always has consistent access
// to the value of a pixel. Thus, everything else competes for access to the
// other port. Currently, this includes the processor, video, and flash.
// HOWEVER, most of these things will probably block each other, so we can
// probably get away with a really naive policy for determining what goes

// Internally, memory is stored in a BRAM of width 8

// TODO: optimize this later. For example, only one of proc_ram, proc_reg, and
// proc_stk will ever be requested at a time, so can probably optimize cycles
// here
module chip8_memory #(
    parameter int WIDTH = 8
) (
    input wire clk_in,
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
    input wire [1:0] proc_type_in,

    // r/w a byte from the video buffer (TODO: how to handle address??)
    input wire [15:0] video_addr_in,
    input wire video_we_in,
    input wire video_valid_in,
    input wire [WIDTH-1:0] video_data_in,

    // flash rom (TODO: add)

    // get value for hdmi module
    input wire [15:0] hdmi_addr_in,

    // readies for each pattern
    output logic proc_ready_out,
    output logic video_ready_out,
    //output logic flash_ready_out,

    // indicates when the result of a r/w to the first port is valid
    output logic proc_valid_out,
    output logic video_valid_out,
    //output logic flash_valid_out,

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
  localparam int MAX_STATE = 3; // for looping counter

  localparam int STATE_WIDTH = 2; // how many bits we need for state
  logic [STATE_WIDTH-1:0] state; // continually cycles through all states

  logic [STATE_WIDTH-1:0] state_out;

  // parameters for first port
  logic [$clog2(DEPTH)-1:0] addr;
  logic we;
  logic [WIDTH-1:0] data_in;

  // parameters for second port
  logic [$clog2(DEPTH)-1:0] hdmi_addr;

  // output is the type of state (TODO: tweak depth???)
  pipeline #(.WIDTH(STATE_WIDTH), .DEPTH(2)) state_pipeline(
      .clk_in(clk_in),
      .rst_in(rst_in),
      .val_in(state),
      .val_out(state_out)
    );

  // temp storage for various params
  logic [11:0] proc_addr;
  logic proc_we;
  logic [WIDTH-1:0] proc_data;
  logic [1:0] proc_type;

  logic [11:0] video_addr;
  logic video_we;
  logic [WIDTH-1:0] video_data;
  logic [1:0] video_type;

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      state <= NONE;
      state_out <= NONE;
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
        we <= video_we;
        data_in <= video_data;
        addr <= RAM_DEPTH + video_addr;
        video_ready_out <= 1;
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
      end else if (video_ready_out && video_valid_in)begin
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
      // determine what to send out
      proc_valid_out <= (state_out == PROC);
      video_valid_out <= (state_out == VIDEO);
    end
  end

  // assigns addr, we, din, hdmi_addr
  always_comb begin
  end

  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(16),
      .RAM_DEPTH(DEPTH)
    ) memory (
      // TODO: assign properly
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
      .clkb(clk_in),
      .web(1'b0), // write-enable (hdmi should never write to ram)
      .dinb(1'b0), // read only, so unnecessary
      .enb(1'b1), // set to 0 to save power
      .regceb(1'b1),
      .rstb(rst_in),
      .doutb(hdmi_data_out)
    );

endmodule // memory

`default_nettype wire
