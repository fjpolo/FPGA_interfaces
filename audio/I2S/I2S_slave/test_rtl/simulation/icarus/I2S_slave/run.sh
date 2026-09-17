#!/bin/bash

# Define paths
TESTBENCH="testbench.v"
RTL_MODULE="${PWD}/../../../../rtl/I2S_slave.v"
OUTPUT="testbench"
WAVEFORM="dump.vcd"

# oss-cad-suite env
echo "        [ICARUS] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "        [ICARUS] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi
# Check if the RTL module exists
if [ ! -f "$RTL_MODULE" ]; then
  echo "        [ICARUS] ERROR: RTL module not found at $RTL_MODULE"
  exit 1
fi

# Compile the testbench and RTL module
echo "        [ICARUS] Compiling testbench and RTL module..."
iverilog -o "$OUTPUT" "$TESTBENCH" "$RTL_MODULE"

# Check if compilation was successful
if [ $? -ne 0 ]; then
  echo "        [ICARUS] ERROR: Compilation failed."
  exit 1
fi

# Run the simulation and generate waveform
echo "        [ICARUS] Running simulation and generating waveform..."
vvp "$OUTPUT" +fst

# Check if simulation was successful
if [ $? -ne 0 ]; then
  echo "        [ICARUS] ERROR: Simulation failed."
  exit 1
fi

# Rename the waveform file to the desired name
if [ -f "dump.vcd" ]; then
  mv "dump.vcd" "$WAVEFORM"
  echo "        [ICARUS] Waveform saved to $WAVEFORM"
else
  echo "        [ICARUS] ERROR: Waveform file not generated."
  exit 1
fi

echo "        [ICARUS] PASS: Simulation completed successfully."