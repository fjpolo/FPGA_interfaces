#!/bin/bash

# Source the OSS CAD Suite environment
  echo "[TEST] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "[TEST] ailed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

# Loop through all directories in the current directory
for dir in */; do
  # Check if the directory contains a run_all.sh script
  if [ -f "$dir/run_all.sh" ]; then
    echo "[TEST] Running $dir/run_all.sh..."

    # Run the run_all.sh script and capture the exit status
    (cd "$dir" && ./run_all.sh)
    exit_status=$?

    # Check if the script failed
    if [ $exit_status -ne 0 ]; then
      echo "[TEST] I2S_slave failed!"
    else
      echo "[TEST] I2S_slave passed!"
    fi
  else
    echo "[TEST] No run_all.sh found in $dir"
  fi
done