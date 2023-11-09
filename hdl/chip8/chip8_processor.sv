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

    // data received from memory module
    input wire [7:0] mem_data_in,

    // receive instruction/data from memory
    input wire mem_ready_in,
    input wire mem_valid_in,

    // for asking input module for key
    output logic [4:0] req_key_out,

    // common params for querying memory
    output logic [11:0] mem_addr_out,
    output logic mem_we_out,
    output logic mem_valid_out,
    output logic [7:0] mem_data_out,
    output logic [$clog2(PROC_MEM_TYPE_COUNT)-1:0] mem_type_out,

    // sprite drawing info
    output logic [11:0] sprite_addr_out,
    output logic [10:0] sprite_pos_out,

    // audio on
    output logic active_audio_out,

    // debug
    output logic [2:0] error_out
  );

  // primary states
  localparam int IDLE = 0;
  localparam int FETCH = 1;
  localparam int EXECUTE = 2;
  localparam int FINISH = 3;

  logic [1:0] state;
  // tracks different steps within each main state
  logic [4:0] substate;

  localparam int FETCH_TIME = 4;

  // opcode types
  //localparam int SYS = 0; // 0nnn, TODO: apparently this is deprecated???
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
  localparam int LD_BCD = 32; //Fx33
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

  // registers (TODO: delete because we do everything through bram now)
  //logic [8:0] vregs [16]; // registers V0 through V15/VF
  //logic [15:0] ireg; // register I
  //logic [7:0] delay_timer;
  //logic [7:0] sound_timer;
  logic [15:0] pc; // program counter
  //logic [7:0] sp; // stack pointer
  //logic [15:0] stack [16]; // TODO: check if this is distinct from main memory

  always_ff @(posedge clk_in)begin
    // main logic
    if (rst_in)begin
      state <= IDLE;
      substate <= 0;
      pc <= 16'h0;
      //sp <= 0;
      //delay_timer <= 0;
      //sound_timer <= 0;
      error_out <= 0;
      mem_received <= 0;
      mem_sent <= 0;
    end else if (active_in)begin
      // main state machine goes here. states are as follows:
      // - idle (wait until chip8_clk_in)
      // - fetch (get instruction from memory, when receive parse)
      // - execute (massive switch statement for each instruction,
      //     i think variable length execution is fine because most of the
      //     time will be spent in idle anyways)
      // TODO: make all memory fetches use ram_ready_in
      case (state)
        IDLE: begin
          if (chip8_clk_in)begin
            state <= FETCH;
            substate <= 0;
            mem_received <= 0;
            mem_sent <= 0;
          end else begin
            mem_valid_out <= 0;
          end
        end
        FETCH: begin
          // TODO: optimize optimize optimize
          case (substate)
            0: begin // fetch pc high
              if (mem_ready_in)begin // fetch high pc
                mem_addr_out <= 18; // pc high
                mem_we_out <= 0;
                mem_valid_out <= 1;
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_received <= 0;
                mem_sent <= 0;
                substate <= substate + 1;
              end
            end
            1: begin // wait for pc high, fetch pc low
              if (!mem_sent && mem_ready_in)begin
                mem_addr_out <= 19; // pc low
                mem_we_out <= 0;
                mem_valid_out <= 1;
                mem_type_out <= PROC_MEM_TYPE_REG;
                mem_sent <= 1;
              end else begin
                mem_valid_out <= 0;
              end

              if (mem_valid_in)begin
                pc[11:8] <= mem_data_in[3:0];
                mem_received <= 1;
              end
              // if both actions have completed, proceed
              if ((mem_valid_in|mem_received) && (mem_ready_in|mem_sent))begin
                substate <= substate+1;
              end
            end
            2: begin // wait for pc low, then fetch opcode high
              if (mem_valid_in)begin
                pc[7:0] <= mem_data_in;
                mem_addr_out <= {pc[11:8], mem_data_in}; // opcode high
                mem_we_out <= 0;
                mem_valid_out <= 1;
                mem_type_out <= PROC_MEM_TYPE_RAM;

                mem_received <= 0;
                mem_sent <= 0;
                substate <= substate + 1;
              end else begin
                mem_valid_out <= 0;
              end
            end
            3: begin // wait for opcode high, fetch opcode low
              if (!mem_sent && mem_ready_in)begin
                mem_addr_out <= pc + 1; // opcode low
                mem_we_out <= 0;
                mem_valid_out <= 1;
                mem_type_out <= PROC_MEM_TYPE_RAM;
                mem_sent <= 1;
                // now that opcode has been fully requested, increment pc here
                pc <= pc + 2;
              end else begin
                mem_valid_out <= 0;
              end

              if (mem_valid_in)begin
                opcode[15:8] <= mem_data_in;
                mem_received <= 1;
              end
              if ((mem_valid_in|mem_received) && (mem_ready_in|mem_sent))begin
                mem_received <= 0;
                mem_sent <= 0;
                substate <= substate+1;
              end
            end
            4: begin // wait for opcode low
              mem_valid_out <= 0;
              if (mem_valid_in)begin
                opcode[7:0] <= mem_data_in;
                state <= EXECUTE;
                substate <= 0;
                case (opcode[15:12])
                  4'h0: begin
                    // TODO: handle RET
                    if ({opcode[11:8], mem_data_in} == 8'h0E0)begin
                      instr <= CLS;
                    end else begin
                      error_out <= 1;
                    end
                  end
                  // TODO: all other leading digits/instructions
                  4'h1: instr <= JP_ABS;
                  4'h6: instr <= LD_IMM;
                  4'h7: instr <= ADD_IMM;
                  4'hA: instr <= LD_I;
                  4'hD: instr <= DRW;
                  default: begin
                    error_out <= ERR_PARSE;
                  end
                endcase
              end
            end
            default: begin
              error_out <= ERR_PARSE;
            end
          endcase
        end
        EXECUTE: begin
          // TODO: 00E0, 1nnn, 6xkk, 7xkk, Annn, Dxyn
          case (instr)
            CLS: begin // 00E0
              // set all pixels to 0 (TODO: actually implement)
              state <= FINISH;
              substate <= 0;
            end
            JP_ABS: begin // 1nnn
              // set pc to nnn
              pc <= opcode[11:0];
              state <= FINISH;
              substate <= 0;
            end
            LD_IMM: begin // 6xkk
              // set Vx to kk
              if (mem_ready_in)begin
                mem_addr_out <= 5'(opcode[11:8]);
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= opcode[7:0];
                mem_type_out <= PROC_MEM_TYPE_REG;
                state <= FINISH;
                substate <= 0;
              end
            end
            ADD_IMM: begin // 7xkk
              // set Vx to Vx + kk
              case (substate)
                0: begin // fetch Vx
                  mem_addr_out <= 5'(opcode[11:8]);
                  mem_we_out <= 0;
                  mem_valid_out <= 1;
                  mem_type_out <= PROC_MEM_TYPE_REG;
                  substate <= substate + 1;
                end
                1: begin // write Vx + kk
                  if (mem_valid_in)begin
                    mem_addr_out <= 5'(opcode[11:8]);
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= mem_data_in + opcode[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
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
            LD_I: begin // Annn
              // set I to nnn
              case (substate)
                0: begin
                  if (mem_ready_in)begin
                    mem_addr_out <= 16; // Ih
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= 8'(opcode[11:8]);
                    mem_type_out <= PROC_MEM_TYPE_REG;
                    substate <= substate + 1;
                  end else begin
                    mem_valid_out <= 0;
                  end
                end
                1: begin
                  if (mem_ready_in)begin
                    mem_addr_out <= 17; // Ih
                    mem_we_out <= 1;
                    mem_valid_out <= 1;
                    mem_data_out <= opcode[7:0];
                    mem_type_out <= PROC_MEM_TYPE_REG;
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
            DRW: begin // Dxyn
              // display n-byte sprite defined at memory location I
              // beginning at pixel (Vx, Vy)
              // if collision, set VF to 1
              // TODO: actually implement
              state <= FINISH;
              substate <= 0;
            end
            default: begin
              error_out <= ERR_PARSE;
            end
          endcase
        end
        FINISH: begin
          // write updated pc to bram
          case (substate)
            0: begin // write high byte
              if (mem_ready_in)begin
                mem_addr_out <= 18; // pc high
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= pc[15:8];
                mem_type_out <= PROC_MEM_TYPE_REG;
                substate <= substate + 1;
              end else begin
                mem_valid_out <= 0;
              end
            end
            1: begin
              if (mem_ready_in)begin
                mem_addr_out <= 19; // pc low
                mem_we_out <= 1;
                mem_valid_out <= 1;
                mem_data_out <= pc[7:0];
                mem_type_out <= PROC_MEM_TYPE_REG;

                state <= IDLE;
                substate <= 0;
              end else begin
                mem_valid_out <= 0;
              end
            end
            default: begin
              error_out <= ERR_STATE;
            end
          endcase
        end
        default: begin
          error_out <= ERR_STATE;
        end
      endcase
    end
  end
  // handle timers independently
  //always_ff @(posedge clk_in)begin
  //  if (timer_decr_in)begin
  //    delay_timer <= delay_timer == 0 ? 0 : delay_timer - 1;
  //    sound_timer <= sound_timer == 0 ? 0 : sound_timer - 1;
  //  end
  //end
  //assign active_audio_out = sound_timer > 0;

endmodule // processor

`default_nettype wire
