main: hdl/* hdl/chip8/* xdc/*
	./remote/r.py build.py build.tcl hdl/ xdc/ obj/ data/

flash: main
	openFPGALoader -b arty_s7_50 obj/final.bit
