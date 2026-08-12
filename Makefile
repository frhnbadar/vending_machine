#==================================================
# Vending Machine - Simulation Makefile
#==================================================

IVERILOG = iverilog
VVP      = vvp

RTL = rtl/vending_machine.sv
TB  = tb/testbench.sv

OUT = sim/vending_machine_sim
VCD = dump.vcd


#==================================================
# Default target
#==================================================

all: compile run


#==================================================
# Compile
#==================================================

compile:
	mkdir -p sim
	$(IVERILOG) -g2012 -o $(OUT) $(RTL) $(TB)


#==================================================
# Run simulation
#==================================================

run:
	$(VVP) $(OUT)


#==================================================
# Open waveform with GTKWave
#==================================================

wave:
	gtkwave $(VCD)


#==================================================
# Clean generated files
#==================================================

clean:
	rm -rf sim
	rm -f $(VCD)


.PHONY: all compile run wave clean