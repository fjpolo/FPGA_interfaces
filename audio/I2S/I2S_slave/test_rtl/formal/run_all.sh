#!/bin/bash

# Source the OSS CAD Suite environment
echo "    [FORMAL] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "    [FORMAL] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

# Loop through all directories in the current directory
for dir in */; do
  # Check if the directory contains a run.sh script
  if [ -f "$dir/run.sh" ]; then
    echo "    [FORMAL] Running $dir/run.sh..."

    # Run the run.sh script and capture the exit status
    (cd "$dir" && ./run.sh >> template_log.txt)
    exit_status=$?

    # Check if the script failed
    if [ $exit_status -ne 0 ]; then
      echo "    [FORMAL] FAIL: I2S_slave failed!"
    else
      echo "    [FORMAL] PASS: I2S_slave passed!"
    fi
  else
    echo "    [FORMAL] ERROR: No run.sh found in $dir"
  fi
done