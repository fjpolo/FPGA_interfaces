# !/bin/bash

# oss-cad-suite env
echo "        [VERILATOR] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "        [VERILATOR] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

# Run verilator as linter
echo "        [VERILATOR] Running linter..."
verilator --lint-only --Wall --cc -I${PWD}/../../../rtl/ ${PWD}/../../../rtl/I2S_slave.v
if [ $? -ne 0 ]; then
    echo "        [VERILATOR] FAIL: Verilator linter failed. Exiting script."
    exit 1
fi
echo "        [VERILATOR] PASS: Verilator linter passed!"
