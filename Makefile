VLOG = vlog
VSIM = vsim

VLOG_FLAGS = -sv

DESIGN_SRC = design/quarter_sine_lut.sv design/dds_core.sv design/dual_port_ram_awg.sv
TB_SRC = test/dds_core_tb.sv

TOP_TB = dds_core_tb

AWG_TB = tb_dds_awg
AWG_TB_SRC = test/dds_awg_tb.sv

.PHONY: all build sim gui clean awg_build awg_sim awg_gui

all: sim

build: 
		vlib work
		vmap work work
		$(VLOG) $(VLOG_FLAGS) $(DESIGN_SRC) $(TB_SRC)

sim: build
		$(VSIM) -c -do "run -all; quit" $(TOP_TB)

gui: build
		$(VSIM) -do "add wave -r /*; run -all" $(TOP_TB)

clean:
		rm -rf work transcript vsim.wlf modelsim.ini dds_output_data.csv

awg_build:
		vlib work
		vmap work work
		$(VLOG) $(VLOG_FLAGS) $(DESIGN_SRC) $(AWG_TB_SRC)

awg_sim: awg_build
		$(VSIM) -c -do "run -all; quit" $(AWG_TB)

awg_gui: build
		$(VSIM) -do "add wave -r /*; run -all" $(AWG_TB)
