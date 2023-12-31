main: cfg hdl/* hdl/chip8/* xdc/*
	./remote/r.py build.py build.tcl hdl/ xdc/ obj/ data/

flash: main
	openFPGALoader -b arty_s7_50 obj/final.bit

cfg:
	python3 util/cfg_layout.py

memtest:
	iverilog -g2012 -o sim/sim.out sim/chip8_memory_tb.sv hdl/chip8/chip8_memory.sv hdl/xilinx_true_dual_port_read_first_2_clock_ram.v hdl/pipeline.sv hdl/chip8/chip8_params.sv
	vvp sim/sim.out

proctest:
	iverilog -g2012 -o sim/sim.out sim/chip8_processor_tb.sv hdl/chip8/chip8_memory.sv hdl/xilinx_true_dual_port_read_first_2_clock_ram.v hdl/pipeline.sv hdl/chip8/chip8_params.sv hdl/chip8/chip8_processor.sv hdl/lfsr_16.sv
	vvp sim/sim.out

vidtest:
	iverilog -g2012 -o sim/sim.out sim/chip8_video_tb.sv hdl/chip8/chip8_memory.sv hdl/xilinx_true_dual_port_read_first_2_clock_ram.v hdl/pipeline.sv hdl/chip8/chip8_params.sv hdl/chip8/chip8_video.sv
	vvp sim/sim.out

chiptest:
	iverilog -g2012 -o sim/sim.out sim/chip8_tb.sv $(shell find hdl ! -name 'hdmi_clk_wiz.v' ! -name 'tmds_serializer.sv' ! -name 'audio_clk_wiz.v')
	vvp sim/sim.out
