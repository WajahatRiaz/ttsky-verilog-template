# ODIN simulation — from this directory:
#   make
#   make clean

ifeq ($(INNER),1)

# Must be set before cocotb includes (Makefile.sim auto-detect often picks /usr/bin/python3)
PYTHON_BIN ?= $(abspath $(CURDIR)/.venv/bin/python3)
export PATH := $(dir $(PYTHON_BIN)):$(PATH)
export PYTHON := $(PYTHON_BIN)

SIM ?= icarus
FST ?= -fst
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = \
	project.v \
	sram_sky130_adapters.v \
	odin/ODIN.v \
	odin/aer_out.v \
	odin/controller.v \
	odin/fifo.v \
	odin/izh_neuron.v \
	odin/lif_neuron.v \
	odin/neuron_core.v \
	odin/scheduler.v \
	odin/sdsp_update.v \
	odin/host_if.v \
	odin/synaptic_core.v \
	odin/IZH_neuron_blocks/izh_calcium.v \
	odin/IZH_neuron_blocks/izh_effective_threshold.v \
	odin/IZH_neuron_blocks/izh_input_accumulator.v \
	odin/IZH_neuron_blocks/izh_neuron_state.v \
	odin/IZH_neuron_blocks/izh_stimulation_strength.v \
	odin/LIF_neuron_blocks/lif_calcium.v \
	odin/LIF_neuron_blocks/lif_neuron_state.v

ifneq ($(GATES),yes)
SIM_BUILD = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
else
SIM_BUILD = sim_build/gl
COMPILE_ARGS += -DGL_TEST -DFUNCTIONAL -DUSE_POWER_PINS -DSIM -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v
endif

COMPILE_ARGS += -I$(SRC_DIR) -g2005-sv
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb
COCOTB_TEST_MODULES = test

COCOTB_MAKEFILES_DIR := $(shell $(PYTHON_BIN) -m cocotb_tools.config --makefiles)
include $(COCOTB_MAKEFILES_DIR)/Makefile.inc
include $(COCOTB_MAKEFILES_DIR)/simulators/Makefile.icarus

else

.PHONY: sim clean
.DEFAULT_GOAL := sim

sim:
	@if [ ! -x .venv/bin/python3 ]; then \
		echo "[sim] Creating .venv..."; \
		python3 -m venv .venv; \
	fi
	@echo "[sim] Ensuring cocotb dependencies in .venv..."
	@.venv/bin/pip install -q -r requirements.txt
	@$(MAKE) INNER=1 sim \
		PYTHON_BIN="$(abspath $(CURDIR)/.venv/bin/python3)"

clean:
	rm -rf sim_build results.xml tb.fst tb.vcd .venv

endif
