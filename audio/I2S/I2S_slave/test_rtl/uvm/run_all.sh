#!/bin/bash

# Source the OSS CAD Suite environment
echo "    [UVM] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "    [UVM] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

# Loop through all directories in the current directory
for dir in */; do
  # Check if the directory contains a run_all.sh script
  if [ -f "$dir/run_all.sh" ]; then
    echo "    [UVM] Running $dir/run_all.sh..."

    # Run the run_all.sh script and capture the exit status
    (cd "$dir" && ./run_all.sh >> template_log.txt)
    exit_status=$?

    # Check if the script failed
    if [ $exit_status -ne 0 ]; then
      echo "    [UVM] FAIL: I2S_slave failed!"
    else
      echo "    [UVM] PASS: I2S_slave passed!"
    fi
  else
    echo "    [UVM] ERROR: No run_all.sh found in $dir"
  fi
done