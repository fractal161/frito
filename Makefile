main:
	./remote/r.py build.py build.tcl hdl/ xdc/ obj/

flash: main
	openFPGALoader -b arty_s7_50 obj/final.bit
