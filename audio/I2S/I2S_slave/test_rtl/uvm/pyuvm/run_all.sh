#!/bin/bash

# Loop through all directories in the current directory
for dir in */; do
  # Check if the directory contains a run.sh script
  if [ -f "$dir/run.sh" ]; then
    echo "[UVM][PYUVM] Running $dir/run.sh..."

    # Run the run.sh script and capture the exit status
    (cd "$dir" && ./run.sh >> template_log.txt)
    exit_status=$?

    # Check if the script failed
    if [ $exit_status -ne 0 ]; then
      echo "[UVM][PYUVM] FAIL: I2S_slave failed!"
    else
      echo "[UVM][PYUVM] I2S_slave passed!"
    fi
  else
    echo "[UVM][PYUVM] No run.sh found in $dir"
  fi
done