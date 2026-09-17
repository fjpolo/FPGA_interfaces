#!/bin/bash

# oss-cad-suite env
echo "        [VERILATOR] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "        [VERILATOR] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

RTL_DIR="${PWD}/../../../rtl"

echo "        [VERILATOR] 1/3 Linting I2S_slave (Default: Full Duplex)..."
verilator --lint-only --Wall --cc -I${RTL_DIR} ${RTL_DIR}/I2S_slave.v
if [ $? -ne 0 ]; then
    echo "        [VERILATOR] FAIL: Full Duplex lint failed."
    exit 1
fi

echo "        [VERILATOR] 2/3 Linting I2S_slave (RX Only)..."
verilator --lint-only --Wall --cc -DI2S_SLAVE_RX_ONLY -I${RTL_DIR} ${RTL_DIR}/I2S_slave.v
if [ $? -ne 0 ]; then
    echo "        [VERILATOR] FAIL: RX Only lint failed."
    exit 1
fi

echo "        [VERILATOR] 3/3 Linting I2S_slave (TX Only)..."
verilator --lint-only --Wall --cc -DI2S_SLAVE_TX_ONLY -I${RTL_DIR} ${RTL_DIR}/I2S_slave.v
if [ $? -ne 0 ]; then
    echo "        [VERILATOR] FAIL: TX Only lint failed."
    exit 1
fi

echo "        [VERILATOR] PASS: All 3 configurations passed Verilator linting!"
