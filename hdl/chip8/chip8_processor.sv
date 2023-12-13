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
    input wire [15:0] key_state_in,

    // data received from memory module
    input wire [15:0] mem_data_in,

    // receive instruction/data from memory
    input wire mem_ready_in,
    input wire mem_valid_in,

    // results from video module
    input wire collision_in,
    input wire done_drawing_in,

    // common params for querying memory
    output logic [11:0] mem_addr_out,
    output logic mem_we_out,
    output logic mem_valid_out,
    output logic [15:0] mem_data_out,
    output logic [$clog2(PROC_MEM_TYPE_COUNT)-1:0] mem_type_out,
    output logic mem_size_out,

    // sprite drawing info
    output logic draw_sprite_out,
    output logic [11:0] sprite_addr_out,
    output logic [5:0] sprite_x_out,
    output logic [4:0] sprite_y_out,
    output logic [3:0] sprite_height_out,

    output logic clear_buffer_out,

    // audio on
    output logic active_audio_out,

    output logic [5:0] chip_index_out,

    // debug
    output logic [2:0] error_out
  );

  // primary states
  localparam int IDLE = 0;
  localparam int FETCH = 1;
  localparam int EXECUTE = 2;
  localparam int FINISH = 3;
  localparam int SWITCH = 4;

  logic [2:0] state;
  // tracks different steps within each main state
  logic [5:0] substate;

  // opcode types
  //localparam int SYS = 0; // 0nnn, (ignored by modern interpreters)
  localparam int CLS = 1; // 00E0
  localparam int RET = 2; // 00EE
  localparam int JP_ABS = 3; // 1nnn
  localparam int CALL = 4; // 2nnn
  localparam int SE_IMM = 5; // 3xkk
  localparam int SNE_IMM = 6; // 4xkk
  localparam int SE_REG = 7; // 5xy0
  localparam int LD_IMM = 8; // 6xkk
  localparam int ADD_IMM = 9; // 7xkk
  localparam int LD_REG = 10; // 8xy0
  localparam int OR = 11; // 8xy1
  localparam int AND = 12; // 8xy2
  localparam int XOR = 13; // 8xy3
  localparam int ADD_REG = 14; // 8xy4
  localparam int SUB = 15; // 8xy5
  localparam int SHR = 16; // 8xy6
  localparam int SUBN = 17; // 8xy7
  localparam int SHL = 18; // 8xyE
  localparam int SNE_REG = 19; // 9xy0
  localparam int LD_I = 20; // Annn
  localparam int JP_REL = 21; // Bnnn
  localparam int RND = 22; // Cxkk
  localparam int DRW = 23; // Dxyn
  localparam int SKP = 24; // Ex9E
  localparam int SKNP = 25; // ExA1
  localparam int LD_RDT = 26; // Fx07
  localparam int LD_KEY = 27; // Fx0A
  localparam int LD_WDT = 28; // Fx15
  localparam int LD_WST = 29; // Fx18
  localparam int ADD_I = 30; // Fx1E
  localparam int LD_SPR = 31; // Fx29
  localparam int LD_BCD = 32; // Fx33
  localparam int LD_WREG = 33; // Fx55
  localparam int LD_RREG = 34; // Fx65

  logic [15:0] opcode;
  logic [5:0] instr;

  // error codes
  localparam int ERR_PARSE = 1;
  localparam int ERR_STATE = 2;
  localparam int ERR_EXEC = 3;

  // utility variable to keep track of when the mem module has respond
  logic mem_received;
  logic mem_sent;

  // temporary vars when requesting from memory
  logic [7:0] reg_tmp;
  logic [15:0] addr_tmp; // used for I and for stack addr
  logic [15:0] pc; // program counter
  //logic [7:0] sp; // stack pointer
  //logic [15:0] stack [16];

  logic [15:0] key_snapshot;
  logic [15:0] last_key_snapshot;
  logic [15:0] keys_just_pressed;
  logic [15:0] keys_released;
  assign keys_released = keys_just_pressed & (~key_snapshot);

  logic [11:0] sprite_addr;
  logic [5:0] sprite_x;

  logic [15:0] seed;
  logic [15:0] random;
  lfsr_16 lfsr (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .seed_in(seed),
      .q_out(random)
    );

  logic pending_timer_decr;

  // schedule a timer decrement
  always_ff @(posedge clk_in)begin
    if (state == FINISH && substate == 1 && mem_ready_in)begin
      pending_timer_decr <= 0;
    end else begin
      pending_timer_decr <= pending_timer_decr | timer_decr_in;
    end
  end
  always_ff @(posedge clk_in)begin
    // main logic
    if (rst_in)begin
      state <= IDLE;
      seed <= 16'h8988;
      substate <= 0;
      pc <= 16'h0;
      //sp <= 0;
      //delay_timer <= 0;
      //sound_timer <= 0;
      error_out <= 0;
      mem_received <= 0;
      mem_sent <= 0;
      mem_valid_out <= 0;
      clear_buffer_out <= 0;
      draw_sprite_out <= 0;
      active_audio_out <= 0;

      keys_just_pressed <= 0;
      chip_index_out <= 0;
    end else if (active_in)begin
      // main state machine goes here. states are as follows:
      // - idle (wait until chip8_clk_in)
      // - fetch (get instruction from memory, when receive parse)
      // - execute (massive switch statement for each instruction,
      //     i think variable length execution is fine because most of the
      //     time will be spent in idle anyways)
      case (state)
        IDLE: begin
          if (chip8_clk_in)begin
            state <= FETCH;
            chip_index_out <= 0;
            substate <= 0;
            last_key_snapshot <= key_snapshot;
            key_snapshot <= key_state_in;
          end else begin
            mem_valid_out <= 0;
          end
        end
        FETCH: begin
          // TODO: optimize optimize optimize
          case (substate)
            0: begin // fetch pc
              if (mem_ready_in)begin
                mem_addr_out <= REG_PC;
                mem_we_out <= 0;
                mem_valid_out <= 1;
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 1;
                substate <= substate + 1;
              end else begin
                mem_valid_out <= 0;
              end
            end
            1: begin // wait for pc, fetch opcode
              if (mem_valid_in)begin
                pc <= mem_data_in+2;
                mem_addr_out <= mem_data_in[11:0];
                mem_we_out <= 0;
                mem_valid_out <= 1;
                mem_type_out <= PROC_MEM_TYPE_RAM;
                mem_size_out <= 1;
                substate <= substate + 1;
              end else begin
                mem_valid_out <= 0;
              end
            end
            2: begin // wait for opcode, decode to instruction
              mem_valid_out <= 0;
              if (mem_valid_in)begin
                opcode <= mem_data_in;
                state <= EXECUTE;
                substate <= 0;
                case (mem_data_in[15:12])
                  4'h0: case(mem_data_in[11:0])
                    12'h0E0: instr <= CLS;
                    12'h0EE: instr <= RET;
                    default: error_out <= ERR_PARSE;
                  endcase
                  // TODO: all other leading digits/instructions
                  4'h1: instr <= JP_ABS;
                  4'h2: instr <= CALL;
                  4'h3: instr <= SE_IMM;
                  4'h4: instr <= SNE_IMM;
                  4'h5: instr <= SE_REG;
                  4'h6: instr <= LD_IMM;
                  4'h7: instr <= ADD_IMM;
                  4'h8: case (mem_data_in[3:0])
                    4'h0: instr <= LD_REG;
                    4'h1: instr <= OR;
                    4'h2: instr <= AND;
                    4'h3: instr <= XOR;
                    4'h4: instr <= ADD_REG;
                    4'h5: instr <= SUB;
                    4'h6: instr <= SHR;
                    4'h7: instr <= SUBN;
                    4'hE: instr <= SHL;
                    default: error_out <= ERR_PARSE;
                  endcase
                  4'h9: instr <= SNE_REG;
                  4'hA: instr <= LD_I;
                  4'hB: instr <= JP_REL;
                  4'hC: instr <= RND;
                  4'hD: instr <= DRW;
                  4'hE: case (mem_data_in[7:0])
                    8'h9E: instr <= SKP;
                    8'hA1: instr <= SKNP;
                    default: error_out <= ERR_PARSE;
                  endcase
                  4'hF: case (mem_data_in[7:0])
                    8'h07: instr <= LD_RDT;
                    8'h0A: instr <= LD_KEY;
                    8'h15: instr <= LD_WDT;
                    8'h18: instr <= LD_WST;
                    8'h1E: instr <= ADD_I;
                    8'h29: instr <= LD_SPR;
                    8'h33: instr <= LD_BCD;
                    8'h55: instr <= LD_WREG;
                    8'h65: instr <= LD_RREG;
                    default: error_out <= ERR_PARSE;
                  endcase
                  default: error_out <= ERR_PARSE;
                endcase
              end
            end
            default: error_out <= ERR_PARSE;
          endcase
        end
        EXECUTE: begin
          case (instr)
            CLS: begin // 00E0
              // set all pixels to 0
              case (substate)
                0: begin // ask video module to clear everything
                  clear_buffer_out <= 1;
                  substate <= substate + 1;
                end
                1: begin // wait for video module to finish
                  if (done_drawing_in)begin
                    state <= FINISH;
                    substate <= 0;
                  end
                  clear_buffer_out <= 0;
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            RET: begin // 00EE
              case (substate)
                0: begin // fetch stack pointer
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_SP;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // decr, then fetch stack addr
                  if (mem_valid_in)begin
                    reg_tmp <= mem_data_in - 1;
                    mem_addr_out <= (mem_data_in - 1) << 1;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_STK;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // wait, then set pc/write new sp
                  if (mem_valid_in)begin
                    pc <= mem_data_in;
                    mem_addr_out <= REG_SP;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            JP_ABS: begin // 1nnn
              // set pc to nnn
              pc <= opcode[11:0];
              state <= FINISH;
              substate <= 0;
            end
            CALL: begin // 2nnn
              case (substate)
                0: begin // fetch sp
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_SP;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write pc high to stack
                  if (mem_valid_in)begin
                    reg_tmp <= mem_data_in;
                    mem_addr_out <= mem_data_in << 1;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= pc[15:8];
                    mem_type_out <= PROC_MEM_TYPE_STK;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write pc low to stack
                  if (mem_ready_in)begin
                    mem_addr_out <= (reg_tmp << 1) + 1;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= pc[7:0];
                    mem_type_out <= PROC_MEM_TYPE_STK;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                3: begin // write new sp to stack
                  if (mem_ready_in)begin
                    // set pc
                    pc <= 16'(opcode[11:0]);
                    mem_addr_out <= REG_SP;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp + 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SE_IMM: begin // 3xkk
              case (substate)
                0: begin // fetch Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= 12'(opcode[11:8]); // Vx
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // wait for Vx
                  mem_valid_out <= 0;
                  if (mem_valid_in)begin
                    if (mem_data_in[7:0] == opcode[7:0])begin
                      pc <= pc + 2;
                    end
                    state <= FINISH;
                    substate <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SNE_IMM: begin // 4xkk
              case (substate)
                0: begin // fetch Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= 12'(opcode[11:8]); // Vx
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // wait for Vx
                  mem_valid_out <= 0;
                  if (mem_valid_in)begin
                    if (mem_data_in[7:0] != opcode[7:0])begin
                      pc <= pc + 2;
                    end
                    state <= FINISH;
                    substate <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SE_REG: begin // 5xy0
              case (substate)
                0: begin // fetch Vx/Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // compare Vx and Vy
                  mem_valid_out <= 0;
                  if (mem_valid_in)begin
                    if (mem_data_in[15:8] == mem_data_in[7:0])begin
                      pc <= pc + 2;
                    end
                    state <= FINISH;
                    substate <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_IMM: begin // 6xkk
              // set Vx to kk
              if (mem_ready_in)begin
                mem_addr_out <= 5'(opcode[11:8]);
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= opcode[7:0];
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 0;
                state <= FINISH;
                substate <= 0;
              end else begin
                mem_valid_out <= 0;
              end
            end
            ADD_IMM: begin // 7xkk
              // set Vx to Vx + kk
              case (substate)
                0: begin // fetch Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write Vx + kk
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in + opcode[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_REG: begin // 8xy0
              // set Vx to Vy
              case (substate)
                0: begin
                  if (mem_ready_in)begin
                    mem_addr_out <= 12'(opcode[7:4]);
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write Vy to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            OR: begin // 8xy1
              case (substate)
                0: begin // fetch Vx and Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write Vy | Vx to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in[15:8] | mem_data_in[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write 0 to VF
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= 0;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            AND: begin // 8xy2
              case (substate)
                0: begin // fetch Vx and Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write Vy & Vx to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in[15:8] & mem_data_in[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write 0 to VF
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= 0;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            XOR: begin // 8xy3
              case (substate)
                0: begin // fetch Vx and Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write Vy ^ Vx to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in[15:8] ^ mem_data_in[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate+1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write 0 to VF
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= 0;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            ADD_REG: begin // 8xy4
              case (substate)
                0: begin // fetch Vx and Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // then write Vy + Vx to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= 8'(mem_data_in[15:8] + mem_data_in[7:0]);
                    reg_tmp <= (9'(mem_data_in[15:8]) + 9'(mem_data_in[7:0]) >= 9'h100);
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write overflow to VF
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SUB: begin // 8xy5
              case (substate)
                0: begin // fetch Vx and Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write Vx - Vy to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in[15:8] - mem_data_in[7:0];
                    reg_tmp <= (mem_data_in[15:8] >= mem_data_in[7:0]);
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write underflow to VF
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SHR: begin // 8xy6
              // TODO: schip8 compatibility
              case (substate)
                0: begin // fetch Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= 12'(opcode[7:4]); // Vy
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // wait for Vy, then write Vy >> 1 to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in >> 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                    reg_tmp <= mem_data_in[0];
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin
                  if (mem_ready_in)begin // write shifted-out bit to VF
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SUBN: begin // 8xy7
              case (substate)
                0: begin // fetch Vx and Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // wait for Vx, then write Vy - Vx to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in[7:0] - mem_data_in[15:8];
                    reg_tmp <= (mem_data_in[7:0] >= mem_data_in[15:8]);
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write underflow to VF
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SHL: begin // 8xyE
              // TODO: schip8 compatibility
              case (substate)
                0: begin // fetch Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= 12'(opcode[7:4]); // Vy
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // wait for Vy, then write Vy << 1 to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= 12'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in << 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                    reg_tmp <= mem_data_in[7];
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin
                  if (mem_ready_in)begin // write shifted-out bit to VF
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SNE_REG: begin // 9xy0
              case (substate)
                0: begin // fetch Vx and Vy
                  if (mem_ready_in)begin
                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // wait for Vx, then compare Vx and Vy
                  mem_valid_out <= 0;
                  if (mem_valid_in)begin
                    if (mem_data_in[15:8] != mem_data_in[7:0])begin
                      pc <= pc + 2;
                    end
                    state <= FINISH;
                    substate <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_I: begin // Annn
              // set I to nnn
              case (substate)
                0: begin
                  if (mem_ready_in)begin // write Ih
                    mem_addr_out <= REG_I; // Ih
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= 8'(opcode[11:8]);
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin
                  if (mem_ready_in)begin // write Il
                    mem_addr_out <= REG_I+1; // Il
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= opcode[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            JP_REL: begin // Bnnn
              case (substate)
                0: begin
                  if (mem_ready_in)begin // fetch V0
                    mem_addr_out <= REG_V0;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin
                  if (mem_valid_in)begin // write relative pc address
                    pc <= mem_data_in[7:0] + opcode[11:0];
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            RND: begin // Cxkk
              // write random & kk to Vx
              if (mem_ready_in)begin
                mem_addr_out <= opcode[11:8];
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= random[7:0] & opcode[7:0];
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 0;
                state <= FINISH;
                substate <= 0;
              end else begin
                mem_valid_out <= 0;
              end
            end
            DRW: begin // Dxyn
              // display n-byte sprite defined at memory location I
              // beginning at pixel (Vx, Vy)
              // if collision, set VF to 1
              case (substate)
                0: begin // fetch I
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_I;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // fetch Vx and Vy
                  if (mem_valid_in)begin
                    sprite_addr <= 12'(mem_data_in);

                    mem_addr_out <= {4'b1000, opcode[11:4]};
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // make request
                  if (mem_valid_in)begin
                    draw_sprite_out <= 1;
                    sprite_addr_out <= sprite_addr;
                    sprite_x_out <= mem_data_in[15:8];
                    sprite_y_out <= mem_data_in[7:0];
                    sprite_height_out <= opcode[4:0];
                    substate <= substate+1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                3: begin
                  mem_valid_out <= 0;
                  if (done_drawing_in)begin
                    substate <= substate+1;
                  end
                  draw_sprite_out <= 0;
                end
                4: begin
                  if (mem_ready_in)begin // write collision bit
                    mem_addr_out <= REG_VF;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= 8'(collision_in);
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SKP: begin // Ex9E
              case (substate)
                0: begin // fetch Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= 12'(opcode[11:8]); // Vx
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // check if key is pressed
                  mem_valid_out <= 0;
                  if (mem_valid_in)begin
                    if (mem_data_in <= 8'h0F
                      && key_snapshot[mem_data_in[3:0]]
                    )begin
                      pc <= pc + 2;
                    end
                    state <= FINISH;
                    substate <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            SKNP: begin // ExA1
              case (substate)
                0: begin // fetch Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= 12'(opcode[11:8]); // Vx
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // check if key is pressed
                  if (mem_valid_in)begin
                    if (mem_data_in < 8'h10
                      && !key_snapshot[mem_data_in[3:0]]
                    )begin
                      pc <= pc + 2;
                    end
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_RDT: begin // Fx07
              case (substate)
                0: begin // fetch dt
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_DT;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write value to Vx
                  if (mem_valid_in)begin
                    mem_addr_out <= opcode[11:8];
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_KEY: begin // Fx0A
              case (substate)
                0: begin // fetch key_state
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_KEYS;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin
                  mem_valid_out <= 0;
                  if (mem_valid_in)begin
                    keys_just_pressed <= mem_data_in;
                    substate <= substate + 1;
                  end
                end
                2: begin
                  // actually do the check
                  keys_just_pressed <= keys_just_pressed | (key_snapshot & ~last_key_snapshot);
                  if (keys_released != 0)begin
                    // honestly too tired to figure out how to do this right
                    if (keys_released[0])begin
                      reg_tmp <= 0;
                    end else if (keys_released[1])begin
                      reg_tmp <= 1;
                    end else if (keys_released[2])begin
                      reg_tmp <= 2;
                    end else if (keys_released[3])begin
                      reg_tmp <= 3;
                    end else if (keys_released[4])begin
                      reg_tmp <= 4;
                    end else if (keys_released[5])begin
                      reg_tmp <= 5;
                    end else if (keys_released[6])begin
                      reg_tmp <= 6;
                    end else if (keys_released[7])begin
                      reg_tmp <= 7;
                    end else if (keys_released[8])begin
                      reg_tmp <= 8;
                    end else if (keys_released[9])begin
                      reg_tmp <= 9;
                    end else if (keys_released[10])begin
                      reg_tmp <= 10;
                    end else if (keys_released[11])begin
                      reg_tmp <= 11;
                    end else if (keys_released[12])begin
                      reg_tmp <= 12;
                    end else if (keys_released[13])begin
                      reg_tmp <= 13;
                    end else if (keys_released[14])begin
                      reg_tmp <= 14;
                    end else begin
                      reg_tmp <= 15;
                    end
                    substate <= 3;
                  end else begin
                    pc <= pc-2;
                    substate <= 4;
                  end
                end
                3: begin // write to Vx
                  keys_just_pressed <= 0;
                  if (mem_ready_in)begin
                    mem_addr_out <= opcode[11:8];
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate+1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                4: begin // write high of keys_just_pressed
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_KEYS;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= keys_just_pressed[15:8];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                5: begin // write low of keys_just_pressed
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_KEYS+1;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= keys_just_pressed[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                //6: begin
                //  if (mem_ready_in)begin
                //    state <= FINISH;
                //    substate <= 0;
                //  end else begin
                //    mem_valid_out <= 0;
                //  end
                //end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_WDT: begin // Fx15
              case (substate)
                0: begin // fetch Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= opcode[11:8];
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write value to DT
                  if (mem_valid_in)begin
                    mem_addr_out <= REG_DT;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_WST: begin // Fx18
              case (substate)
                0: begin // fetch Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= opcode[11:8];
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write value to ST
                  if (mem_valid_in)begin
                    mem_addr_out <= REG_ST;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            ADD_I: begin // Fx1E
              case (substate)
                0: begin // fetch I
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_I;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // fetch Vx
                  if (mem_valid_in)begin
                    addr_tmp <= mem_data_in;
                    mem_addr_out <= opcode[11:8];
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write high byte of I+Vx
                  if (mem_valid_in)begin
                    addr_tmp <= addr_tmp + mem_data_in;
                    mem_addr_out <= REG_I;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= (addr_tmp + mem_data_in) >> 8;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                3: begin // write low byte of I+Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_I+1;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= addr_tmp[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_SPR: begin // Fx29
              case (substate)
                0: begin // fetch Vx
                  if (mem_ready_in)begin
                    mem_addr_out <= opcode[11:8];
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // write to I
                  if (mem_valid_in)begin
                    reg_tmp <= mem_data_in[7:0];
                    mem_addr_out <= REG_I; // Ih
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= 0;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate+1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_I+1; // Ih
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= (reg_tmp << 2) + reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_BCD: begin // Fx33
              case (substate)
                0: begin // fetch I
                  if (mem_ready_in)begin
                    mem_addr_out <= REG_I;
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 1;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin // fetch Vx
                  if (mem_valid_in)begin
                    addr_tmp <= mem_data_in;
                    mem_addr_out <= opcode[11:8];
                    mem_we_out <= 0;
                    mem_valid_out <= 1;
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                2: begin // write hundreds digit
                  if (mem_valid_in)begin
                    mem_addr_out <= addr_tmp;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    if (mem_data_in[7:0] >= 8'd200)begin
                      mem_data_out <= 8'd2;
                      reg_tmp <= mem_data_in[7:0] - 8'd200;
                    end else if (mem_data_in[7:0] >= 8'd100)begin
                      mem_data_out <= 8'd1;
                      reg_tmp <= mem_data_in[7:0] - 8'd100;
                    end else begin
                      mem_data_out <= 8'd0;
                      reg_tmp <= mem_data_in[7:0];
                    end
                    mem_type_out <= PROC_MEM_TYPE_RAM;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                3: begin // write tens digit
                  if (mem_ready_in)begin
                    mem_addr_out <= addr_tmp+1;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    if (reg_tmp >= 8'd90)begin
                      mem_data_out <= 8'd9;
                      reg_tmp <= reg_tmp - 8'd90;
                    end else if (reg_tmp >= 8'd80)begin
                      mem_data_out <= 8'd8;
                      reg_tmp <= reg_tmp - 8'd80;
                    end else if (reg_tmp >= 8'd70)begin
                      mem_data_out <= 8'd7;
                      reg_tmp <= reg_tmp - 8'd70;
                    end else if (reg_tmp >= 8'd60)begin
                      mem_data_out <= 8'd6;
                      reg_tmp <= reg_tmp - 8'd60;
                    end else if (reg_tmp >= 8'd50)begin
                      mem_data_out <= 8'd5;
                      reg_tmp <= reg_tmp - 8'd50;
                    end else if (reg_tmp >= 8'd40)begin
                      mem_data_out <= 8'd4;
                      reg_tmp <= reg_tmp - 8'd40;
                    end else if (reg_tmp >= 8'd30)begin
                      mem_data_out <= 8'd3;
                      reg_tmp <= reg_tmp - 8'd30;
                    end else if (reg_tmp >= 8'd20)begin
                      mem_data_out <= 8'd2;
                      reg_tmp <= reg_tmp - 8'd20;
                    end else if (reg_tmp >= 8'd10)begin
                      mem_data_out <= 8'd1;
                      reg_tmp <= reg_tmp - 8'd10;
                    end else begin
                      mem_data_out <= 8'd0;
                      reg_tmp <= reg_tmp;
                    end
                    mem_type_out <= PROC_MEM_TYPE_RAM;
                    mem_size_out <= 0;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                4: begin // write ones digit
                  if (mem_ready_in)begin
                    mem_addr_out <= addr_tmp+2;
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= reg_tmp;
                    mem_type_out <= PROC_MEM_TYPE_RAM;
                    mem_size_out <= 0;
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                default: begin
                  error_out <= ERR_EXEC;
                end
              endcase
            end
            LD_WREG: begin // Fx55
              if (substate == 0)begin
                // fetch I
                if (mem_ready_in)begin
                  mem_addr_out <= REG_I;
                  mem_we_out <= 0;
                  mem_valid_out <= 1;
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  mem_size_out <= 1;
                  substate <= substate + 1;
                end else begin
                  mem_valid_out <= 0;
                end
              end else if (substate == 1)begin
                // store I, write high byte of I+x+1
                if (mem_valid_in)begin
                  addr_tmp <= mem_data_in;

                  mem_addr_out <= REG_I;
                  mem_we_out <= 1;
                  mem_valid_out <= 1;
                  mem_data_out <= (mem_data_in+opcode[11:8]+1) >> 8;
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  mem_size_out <= 0;

                  substate <= substate + 1;
                end else begin
                  mem_valid_out <= 0;
                end
              end else if (substate == 2)begin
                // write low byte of I+x+1
                if (mem_ready_in)begin
                  mem_addr_out <= REG_I+1;
                  mem_we_out <= 1;
                  mem_valid_out <= 1;
                  mem_data_out <= 8'(addr_tmp+opcode[11:8]+1);
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  mem_size_out <= 0;

                  substate <= 4;
                end else begin
                  mem_valid_out <= 0;
                end
              end else if (!substate[0])begin
                // fetch register substate[5:1]-2
                if (mem_ready_in)begin
                  mem_addr_out <= 4'(substate[5:1]-2);
                  mem_we_out <= 0;
                  mem_valid_out <= 1;
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  mem_size_out <= 0;
                  substate <= substate + 1;
                end else begin
                  mem_valid_out <= 0;
                end
              end else begin
                // store at mem location addr + substate[5:1]-2
                if (mem_valid_in)begin
                  mem_addr_out <= addr_tmp + 4'(substate[5:1]-2);
                  mem_we_out <= 1;
                  mem_valid_out <= 1;
                  mem_data_out <= mem_data_in;
                  mem_type_out <= PROC_MEM_TYPE_RAM;
                  mem_size_out <= 0;
                  if (4'(substate[5:1]-2) == opcode[11:8])begin
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    substate <= substate + 1;
                  end
                end else begin
                  mem_valid_out <= 0;
                end
              end
            end
            LD_RREG: begin // Fx65
              if (substate == 0)begin
                // fetch I
                if (mem_ready_in)begin
                  mem_addr_out <= REG_I;
                  mem_we_out <= 0;
                  mem_valid_out <= 1;
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  mem_size_out <= 1;
                  substate <= substate + 1;
                end else begin
                  mem_valid_out <= 0;
                end
              end else if (substate == 1)begin
                // store I, write high byte of I+x+1
                if (mem_valid_in)begin
                  addr_tmp <= mem_data_in;

                  mem_addr_out <= REG_I;
                  mem_we_out <= 1;
                  mem_valid_out <= 1;
                  mem_data_out <= (mem_data_in+opcode[11:8]+1) >> 8;
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  mem_size_out <= 0;

                  substate <= substate + 1;
                end else begin
                  mem_valid_out <= 0;
                end
              end else if (substate == 2)begin
                // write low byte of I+x+1
                if (mem_ready_in)begin
                  mem_addr_out <= REG_I+1;
                  mem_we_out <= 1;
                  mem_valid_out <= 1;
                  mem_data_out <= 8'(addr_tmp+opcode[11:8]+1);
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  mem_size_out <= 0;

                  substate <= 4;
                end else begin
                  mem_valid_out <= 0;
                end
              end else if (!substate[0])begin
                // fetch mem location addr + substate[5:1]-2
                if (mem_ready_in)begin
                  mem_addr_out <= addr_tmp + 4'(substate[5:1]-2);
                  mem_we_out <= 0;
                  mem_valid_out <= 1;
                  mem_type_out <= PROC_MEM_TYPE_RAM;
                  mem_size_out <= 0;
                  substate <= substate + 1;
                end else begin
                  mem_valid_out <= 0;
                end
              end else begin
                // store at register substate[5:1]-2
                if (mem_valid_in)begin
                  mem_addr_out <= 4'(substate[5:1]-2);
                  mem_we_out <= 1;
                  mem_data_out <= mem_data_in;
                  mem_valid_out <= 1;
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  mem_size_out <= 0;
                  if (4'(substate[5:1]-2) == opcode[11:8])begin
                    state <= FINISH;
                    substate <= 0;
                  end else begin
                    substate <= substate + 1;
                  end
                end else begin
                  mem_valid_out <= 0;
                end
              end
            end
            default: begin
              error_out <= ERR_PARSE;
            end
          endcase
        end
        FINISH: begin
          // write updated pc to bram
          case (substate)
            0: begin // write pc high
              if (mem_ready_in)begin
                mem_addr_out <= REG_PC; // pc high
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= pc[15:8];
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 0;
                substate <= substate+1;
              end else begin
                mem_valid_out <= 0;
              end
            end
            1: begin // write pc low
              if (mem_ready_in)begin
                mem_addr_out <= REG_PC+1; // pc low
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= pc[7:0];
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 0;
                if (pending_timer_decr)begin
                  substate <= substate+1;
                  //pending_timer_decr <= 0;
                end else begin
                  state <= SWITCH;
                  substate <= 0;
                end
              end else begin
                mem_valid_out <= 0;
              end
            end
            2: begin // fetch delay timer
              if (mem_ready_in)begin
                mem_addr_out <= REG_DT;
                mem_we_out <= 0;
                mem_valid_out <= 1;
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 0;
                substate <= substate+1;
              end else begin
                mem_valid_out <= 0;
              end
            end
            3: begin // write delay timer
              if (mem_valid_in)begin
                mem_addr_out <= REG_DT;
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= (mem_data_in[7:0] == 0) ? 0 : mem_data_in[7:0]-1;
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 0;
                substate <= substate+1;
              end else begin
                mem_valid_out <= 0;
              end
            end
            4: begin // fetch sound timer
              if (mem_ready_in)begin
                mem_addr_out <= REG_ST;
                mem_we_out <= 0;
                mem_valid_out <= 1;
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 0;
                substate <= substate+1;
              end else begin
                mem_valid_out <= 0;
              end
            end
            5: begin // write sound timer, set audio playback
              if (mem_valid_in)begin
                mem_addr_out <= REG_ST;
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= (mem_data_in[7:0] == 0) ? 0 : mem_data_in[7:0]-1;
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_size_out <= 0;
                state <= SWITCH;
                substate <= 0;

                // only track audio for top-left instance
                if (chip_index_out == 0) begin
                  active_audio_out <= (mem_data_in[7:0] > 1);
                end
              end else begin
                mem_valid_out <= 0;
              end
            end
            default: begin
              error_out <= ERR_STATE;
            end
          endcase
        end
        SWITCH: begin
          // disgusting hack
          if (substate == 0)begin
            mem_valid_out <= 1;
            mem_we_out <= 0;
          end else begin
            mem_valid_out <= 0;
          end
          // wait a few cycles for write to propogate
          if (substate == 6)begin
            substate <= 0;
            if (chip_index_out == 35)begin
              chip_index_out <= 0;
              state <= IDLE;
            end else begin
              chip_index_out <= chip_index_out + 1;
              state <= FETCH;
            end
          end else begin
            substate <= substate+1;
          end
        end
        default: begin
          error_out <= ERR_STATE;
        end
      endcase
    end
  end
  //assign active_audio_out = sound_timer > 0;

endmodule // processor

module fetch_word(
  );

endmodule // fetch_word

`default_nettype wire
