#!/bin/bash

# Define paths
YOSYS_SCRIPT="I2S_slave.ys"
RTL_MODULE="I2S_slave.v"

# Source the OSS CAD Suite environment
echo "        [YOSYS] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "        [YOSYS] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

# Copy testbench here
cp ${PWD}/../../../rtl/I2S_slave.v .

# Check if the RTL module exists
if [ ! -f "$RTL_MODULE" ]; then
  echo "        [YOSYS] ERROR: RTL module not found at $RTL_MODULE"
  exit 1
fi

# Compile RTL module with yosys
echo "        [YOSYS] Compiling RTL module with yosys..."
yosys $YOSYS_SCRIPT

# Check if compilation was successful
if [ $? -ne 0 ]; then
  echo "        [YOSYS] ERROR: Compilation failed."
  exit 1
fi
echo "        [YOSYS] PASS: Synthesis passed!"

# Remove testbench from here
rm I2S_slave.v