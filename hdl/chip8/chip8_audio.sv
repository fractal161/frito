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
    input wire [9:0] tone_in, // TODO: decide how to represent
    input wire [2:0] vol_in, // TODO: decide how to represent

    // TODO: audio sample clock

    // signal as 8-bit value (TODO: signed or unsigned?)
    output logic level_out
  );


//============================== Generate clock for Audio =============================================//

  // logic sys_rst;
  // assign sys_rst = btn[0];

	logic clk_m;

  audio_clk_wiz macw (.clk_in(clk_in), .clk_out(clk_m)); //98.3MHz

	logic audio_sample_valid; //single-cycle enable for samples at ~3 kHz (approx)
  logic [10:0] clock_counter; //used for counting for clock generation
  logic [10:0] pdm_counter; //logic for generating 3 kHz audio samples

  localparam PDM_COUNT_PERIOD = 32; //do not change
	localparam NUM_PDM_SAMPLES = 1024; //number of pdm in downsample/decimation/average

  logic inter_clk;
  logic old_inter_clk; //prior mic clock for edge detection
  logic pdm_signal_valid; //single-cycle signal at 3.072 MHz indicating pdm steps

  assign pdm_signal_valid = inter_clk && ~old_inter_clk; //rising edge of clock

   //logic to produce 25 MHz step signal for PWM module
  logic [1:0] pwm_counter;
  logic pwm_step; //single-cycle pwm step
  assign pwm_step = (pwm_counter==2'b11);

  always_ff @(posedge clk_m)begin
    pwm_counter <= pwm_counter+1;
  end

//============================== Generate audio signal (samples at ~3 kHz) =================================//
  
  //generate clock signal for internal clock
  //signal at ~3.072 MHz
  always_ff @(posedge clk_m)begin
    inter_clk <= clock_counter < PDM_COUNT_PERIOD/2;
    clock_counter <= (clock_counter==PDM_COUNT_PERIOD-1)?0:clock_counter+1;
    old_inter_clk <= inter_clk;
  end


  always_ff @(posedge clk_m)begin
    if (pdm_signal_valid)begin
      	pdm_counter         <= (pdm_counter==NUM_PDM_SAMPLES)?0:pdm_counter + 1;
      	audio_sample_valid  <= (pdm_counter==NUM_PDM_SAMPLES);
    end else begin
      	audio_sample_valid <= 0;
    end
  end

//=================================== Instantiate Waveform ==============================================//
	  
  logic [7:0] sine_out;
  logic [7:0] square_out;
  logic [7:0] triangle_out;
  logic [7:0] sawtooth_out;
  
    
  
  //change names 
  //phase increment be input
  //lookup table of phases
  //index into table to get the phase value
    sine_generator my_sine(
        .clk_in(clk_m),
        .rst_in(rst_in),
        .step_in(audio_sample_valid),
        .tone_in(tone_in),
        .amp_out(sine_out)
    );

   square_generator my_square(
        .clk_in(clk_m),
        .rst_in(rst_in),
        .step_in(audio_sample_valid),
        .tone_in(tone_in),
        .amp_out(square_out)
    );

       triangle_generator my_triangle(
        .clk_in(clk_m),
        .rst_in(rst_in),
        .step_in(audio_sample_valid),
        .tone_in(tone_in),
        .amp_out(triangle_out)
    );

       sawtooth_generator my_sawtooth(
        .clk_in(clk_m),
        .rst_in(rst_in),
        .step_in(audio_sample_valid),
        .tone_in(tone_in),
        .amp_out(sawtooth_out)
    );



//=================================== Determine the Output Waveform Based on User Input ==========================//

  //choose which signal to play:
  logic [7:0] audio_data_sel;

    always_comb begin
        if (timbre_in==0)begin
          audio_data_sel = sine_out; //signed
        end else if (timbre_in==1)begin
          audio_data_sel = square_out; //signed
        end else if (timbre_in==2)begin
          audio_data_sel = triangle_out; //signed
        end else if (timbre_in==3) begin
          audio_data_sel = sawtooth_out;
        end
        // end else if (timbre_in==1 && pitch_in==0)begin
        //   audio_data_sel = square_tone_750; //signed
        // end else if (timbre_in==1 && pitch_in==1)begin
        //   audio_data_sel = square_tone_440; //signed
        // end else if (timbre_in==2 && pitch_in==0)begin
        //   audio_data_sel = triangle_tone_750; //signed
        // end else if (timbre_in==2 && pitch_in==0)begin
        //   audio_data_sel = triangle_tone_440; //signed
        // end else if (timbre_in==3 && pitch_in==0)begin
        //   audio_data_sel = sawtooth_tone_750; //signed
        // end else if (timbre_in==3 && pitch_in==1)begin
        //   audio_data_sel = sawtooth_tone_440; //signed
        // end
      end

//=================================== Determine Vol Output based on User Input ===================================//

  logic [7:0] vol_out;

  volume_control vc (.volume_in(vol_in),.signal_in(audio_data_sel), .signal_out(vol_out));

//====================================== Upsample Data using PDM ==============================================//


  logic pdm_out_signal;
 
  pdm my_pdm(
    .clk_in(clk_m),
    .rst_in(rst_in),
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
    assign shift = 3'd7 - volume_in;
    assign signal_out = signal_in>>>shift;
endmodule

`default_nettype wire
