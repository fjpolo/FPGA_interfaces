# =============================================================================
# Makefile for Verilator Simulation
# Author      : @fjpolo
# Description : Compiles Verilog RTL with Verilator, links with C++ testbench,
#               and runs simulation to generate waveform.
# License     : MIT License
#
# Copyright (c) 2025 | @fjpolo
#
# =============================================================================

# --- Define Paths and Names ---
# RTL_DESIGN_TOP_MODULE: The main Verilog design file to be Verilated.
RTL_DESIGN_TOP_MODULE := ../../../../rtl/I2S_slave.v
# CPP_TESTBENCH: The C++ testbench file containing the main simulation logic.
CPP_TESTBENCH := template_tb.cpp

# OUTPUT_NAME: Base name of the RTL top module (e.g., "I2S_slave" from "I2S_slave.v").
# This will also be the base name for the Verilator-generated executable.
OUTPUT_NAME := $(shell basename $(RTL_DESIGN_TOP_MODULE) .v)
# OBJ_DIR: Directory for Verilator's generated C++ files, Makefiles, and intermediate objects.
OBJ_DIR := obj_dir
# WAVEFORM: Name of the generated VCD waveform file.
WAVEFORM := dump.vcd

# VERILATOR_ROOT: Path to your OSS CAD Suite Verilator installation.
# This is used for finding Verilator's global include and library paths.
VERILATOR_ROOT := $(HOME)/oss-cad-suite/share/verilator

# --- C++ Compiler Flags ---
# CXXFLAGS: Flags for the C++ compiler. Using C++17 as required by Verilator.
CXXFLAGS := -std=c++17

# --- Default Target ---
.PHONY: all
all: $(OBJ_DIR)/V$(OUTPUT_NAME) run_sim waveform_check

# --- Clean Target ---
.PHONY: clean
clean:
	@echo "        [MAKE] Cleaning up build directory ($(OBJ_DIR))..."
	$(RM) -r $(OBJ_DIR) $(WAVEFORM)

# --- Verilator Compilation Rule ---
# This rule tells make how to create the Verilated C++ files in OBJ_DIR.
# It explicitly lists the .mk file as a target for dependency tracking.
$(OBJ_DIR)/V$(OUTPUT_NAME).mk: $(RTL_DESIGN_TOP_MODULE)
	@echo "        [MAKE] Compiling Verilog RTL to C++ with Verilator..."
	@mkdir -p $(OBJ_DIR)
	verilator --cc --trace --Mdir $(OBJ_DIR) $(RTL_DESIGN_TOP_MODULE)

# --- C++ Compilation and Linking Rule (Build Executable) ---
# This rule builds the final simulation executable by directly invoking g++.
# It depends on the Verilator-generated archive and your C++ testbench.
$(OBJ_DIR)/V$(OUTPUT_NAME): $(OBJ_DIR)/V$(OUTPUT_NAME)__ALL.a $(OBJ_DIR)/libverilated.a $(CPP_TESTBENCH)
	@echo "        [MAKE] Building simulation executable by linking Verilated C++ with C++ testbench..."
	# Directly invoke g++ to compile and link all components.
	# -I: Include paths for headers.
	# -L: Library search paths.
	# -l: Libraries to link against.
	# -o: Output executable name.
	g++ $(CXXFLAGS) \
		-I$(VERILATOR_ROOT)/include \
		-I$(OBJ_DIR) \
		$(CPP_TESTBENCH) \
		$(OBJ_DIR)/V$(OUTPUT_NAME)__ALL.a \
		-L$(OBJ_DIR) -lverilated -lstdc++ -pthread \
		-o $(OBJ_DIR)/V$(OUTPUT_NAME)

# Make sure libverilated.a and Vtemplate__ALL.a are built by Verilator's Makefile
# before the final link. We explicitly call the sub-make target `Vtemplate__ALL.a`
# and `libverilated.a` to ensure these archives are created.
$(OBJ_DIR)/V$(OUTPUT_NAME)__ALL.a $(OBJ_DIR)/libverilated.a: $(OBJ_DIR)/V$(OUTPUT_NAME).mk
	$(MAKE) -C $(OBJ_DIR) -f V$(OUTPUT_NAME).mk \
		CXXFLAGS="$(CXXFLAGS)" \
		V$(OUTPUT_NAME)__ALL.a libverilated.a


# --- Run Simulation Rule ---
.PHONY: run_sim
run_sim: $(OBJ_DIR)/V$(OUTPUT_NAME)
	@echo "        [MAKE] Running simulation..."
	$(OBJ_DIR)/V$(OUTPUT_NAME)

# --- Waveform Check Rule ---
.PHONY: waveform_check
waveform_check:
	@if [ -f "$(OBJ_DIR)/$(WAVEFORM)" ]; then \
		mv "$(OBJ_DIR)/$(WAVEFORM)" "$(WAVEFORM)"; \
		echo "        [MAKE] Waveform saved to $(WAVEFORM)"; \
	elif [ -f "$(WAVEFORM)" ]; then \
		echo "        [MAKE] Waveform already in $(WAVEFORM)"; \
	else \
		echo "        [MAKE] ERROR: Waveform file not generated."; \
		exit 1; \
	fi
	@echo "        [MAKE] PASS: Simulation completed successfully."

# --- Phony targets (targets that don't correspond to a file) ---
.PHONY: all clean run_sim waveform_check
