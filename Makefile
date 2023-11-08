main:
	./remote/r.py build.py build.tcl hdl/ xdc/ obj/

flash:
	openFPGALoader -b arty_s7_50 obj/final.bit
