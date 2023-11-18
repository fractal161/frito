`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// Plays audio ig
module chip8_audio(
    input wire clk_in,
    input wire rst_in,

    // controls when audio is being played
    input wire active_in,

    // config
    input wire [1:0] timbre_in, // TODO: e.g. sine, triangle, square waves
    input wire [1:0] pitch_in, // TODO: decide how to represent
    input wire [2:0] vol_in, // TODO: decide how to represent

    // TODO: audio sample clock

    // signal as 8-bit value (TODO: signed or unsigned?)
    output logic level_out
  );


//============================== Generate clock for Audio =============================================//
	logic clk_m;
  audio_clk_wiz macw (.clk_in(clk_in), .clk_out(clk_m)); //98.3MHz

	logic audio_sample_valid; //single-cycle enable for samples at ~3 kHz (approx)

  logic [10:0] pdm_counter; //logic for generating 3 kHz audio samples

	localparam NUM_PDM_SAMPLES = 1024; //number of pdm in downsample/decimation/average

  logic old_mic_clk; //prior mic clock for edge detection
  logic sampled_mic_data; //one bit grabbed/held values of mic
  logic pdm_signal_valid; //single-cycle signal at 3.072 MHz indicating pdm steps

  assign pdm_signal_valid = mic_clk && ~old_mic_clk;

  always_ff @(posedge clk_m)begin
    pwm_counter <= pwm_counter+1;
  end

//============================== Generate audio signal (samples at ~3 kHz) =================================//
  always_ff @(posedge clk_m)begin
    if (pdm_signal_valid)begin
      	pdm_counter         <= (pdm_counter==NUM_PDM_SAMPLES)?0:pdm_counter + 1;
      	audio_sample_valid  <= (pdm_counter==NUM_PDM_SAMPLES);
    end else begin
      	audio_sample_valid <= 0;
    end
  end

//=================================== Instantiate Waveform ==============================================//
	  
  logic [7:0] sine_tone_750; //output of sine wave of 750Hz
  logic [7:0] sine_tone_440; //output of sine wave of 440Hz
  logic [7:0] triangle_tone_750; //output of triangle wave of 750Hz
  logic [7:0] triangle_tone_440; //output of triangle wave of 440Hz
  logic [7:0] square_tone_750; //output of square wave of 750Hz
  logic [7:0] square_tone_440; //output of square wave of 440Hz
  logic [7:0] sawtooth_tone_750; //output of sawtooth wave of 750Hz
  logic [7:0] sawtooth_tone_440; //output of sawtooth wave of 440Hz   
    
    
    sine_generator #(
        .PHASE_INCR(32'b1000_0000_0000_0000_0000_0000_0000_0000>>1))
      tone750 (
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .step_in(audio_sample_valid),
        .amp_out(sine_tone_750)
    );

    sine_generator #(
        .PHASE_INCR(((32'b1000_0000_0000_0000_0000_0000_0000_0000>>1)/75)*44))
      tone440 (
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .step_in(audio_sample_valid),
        .amp_out(sine_tone_440)
    );

	  triangle_generator #(
        .PHASE_INCR(32'b1000_0000_0000_0000_0000_0000_0000_0000>>1))
      tone750 (
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .step_in(audio_sample_valid),
        .amp_out(triangle_tone_750)
    );

    triangle_generator #(
        .PHASE_INCR(((32'b1000_0000_0000_0000_0000_0000_0000_0000>>1)/75)*44))
      tone440 (
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .step_in(audio_sample_valid),
        .amp_out(triangle_tone_440)
    );

    square_generator #(
        .PHASE_INCR(32'b1000_0000_0000_0000_0000_0000_0000_0000>>1))
      tone750 (
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .step_in(audio_sample_valid),
        .amp_out(square_tone_750)
    );

    square_generator #(
        .PHASE_INCR(((32'b1000_0000_0000_0000_0000_0000_0000_0000>>1)/75)*44))
      tone440 (
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .step_in(audio_sample_valid),
        .amp_out(square_tone_440)
      );

    sawtooth_generator #(
        .PHASE_INCR(32'b1000_0000_0000_0000_0000_0000_0000_0000>>1))
      tone750 (
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .step_in(audio_sample_valid),
        .amp_out(sawtooth_tone_750)
    );

    sawtooth_generator #(
        .PHASE_INCR(((32'b1000_0000_0000_0000_0000_0000_0000_0000>>1)/75)*44))
      tone440 (
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .step_in(audio_sample_valid),
        .amp_out(sawtooth_tone_440)
      );

//=================================== Determine the Output Waveform Based on User Input ==========================//

    always_comb begin
        if          (timbre_in==0 && pitch_in==0)begin
          audio_data_sel = sine_tone_750; //signed
        end else if (timbre_in==0 && pitch_in==1)begin
          audio_data_sel = sine_tone_440; //signed
        end else if (timbre_in==1 && pitch_in==0)begin
          audio_data_sel = square_tone_750; //signed
        end else if (timbre_in==1 && pitch_in==1)begin
          audio_data_sel = square_tone_440; //signed
        end else if (timbre_in==2 && pitch_in==0)begin
          audio_data_sel = triangle_tone_750; //signed
        end else if (timbre_in==2 && pitch_in==0)begin
          audio_data_sel = triangle_tone_440; //signed
        end else if (timbre_in==3 && pitch_in==0)begin
          audio_data_sel = sawtooth_tone_750; //signed
        end else if (timbre_in==3 && pitch_in==1)begin
          audio_data_sel = sawtooth_tone_440; //signed
        end
      end

//=================================== Determine Vol Output based on User Input ===================================//

  logic [7:0] vol_out;

  volume_control vc (.volume_in(vol_in),.signal_in(audio_data_sel), .signal_out(vol_out));

//====================================== Upsample Data using PDM ==============================================//


  logic pdm_out_signal;
 
  pdm my_pdm(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .level_in(vol_out),
    .tick_in(pdm_signal_valid),
    .pdm_out(pdm_out_signal)
  );


//====================================== Output Sound =========================================================//

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
        level_out <= 0;
    end else begin
      	if (active_in) begin
            level_out <= pdm_out_signal;
        end else begin
            level_out <= 0;
        end
    end
  end


endmodule // input

//Volume Control
module volume_control (
  input wire [2:0] volume_in,
  input wire signed [7:0] signal_in,
  output logic signed [7:0] signal_out);
    logic [2:0] shift;
    assign shift = 3'd7 - vol_in;
    assign signal_out = signal_in>>>shift;
endmodule

`default_nettype wire
