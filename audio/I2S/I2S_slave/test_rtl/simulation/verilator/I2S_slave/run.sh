#!/bin/bash

# Source the OSS CAD Suite environment
echo "          [VERILATOR] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "          [VERILATOR] FAIL: Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

make