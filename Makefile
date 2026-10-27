filename = top
pcf_file = iceBlinkPico.pcf

build:
	yosys -p "synth_ice40 -top top -json $(filename).json" $(filename).sv
	nextpnr-ice40 --up5k --package sg48 --json $(filename).json --pcf $(pcf_file) --asc $(filename).asc
	icepack $(filename).asc $(filename).bin

# Testbench that checks the Game of Life rules
sim:
	iverilog -g2012 -o sim.out game_of_life_tb.sv
	vvp sim.out

# Quick test of the whole design at startup
sim_top:
	iverilog -g2012 -o sim.out top_tb.sv
	vvp sim.out

# Report figures, made from the output of make sim
# Set up once with python3 -m venv .venv and then .venv/bin/pip install matplotlib
figures:
	.venv/bin/python make_figures.py

# Open the testbench waveform in GTKWave with the useful signals already shown
wave:
	gtkwave game_of_life_tb.vcd game_of_life_tb.gtkw

prog: build
	dfu-util --device 1d50:6146 --alt 0 -R -D $(filename).bin

clean:
	rm -rf $(filename).blif $(filename).asc $(filename).json $(filename).bin sim.out test.out *.vcd figures

.PHONY: build sim sim_top figures wave prog clean
