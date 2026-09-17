#!/bin/bash

# Source the OSS CAD Suite environment
echo "        [SBY] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "        [SBY] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

# Copy original rtl here
cp ${PWD}/../../../../rtl/I2S_slave.v .

# Build and run icaris UVM
iverilog -g2012 -I/path/to/uvm-1.2/src -D UVM_NO_DEPRECATED -o simv tb_top.sv dut_wrapper.sv I2S_slave.v
vvp -n simv +UVM_TESTNAME=template_test +UVM_VERBOSITY=UVM_MEDIUM

# Remove testbench
# rm I2S_slave.v