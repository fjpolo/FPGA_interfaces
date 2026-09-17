#!/bin/bash

# Source the OSS CAD Suite environment
echo "    [MUTATION] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "[MUTATION] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

# Loop through all directories in the current directory
for dir in */; do
  # Check if the directory contains a run.sh script
  if [ -f "$dir/run.sh" ]; then
    echo "    [MUTATION] Running $dir/run.sh..."

    # Run the run.sh script and capture the exit status
    (cd "$dir" && ./run.sh >> template_log.txt)
    exit_status=$?

    # Check for EQGAP and FMONLY
    if grep -q "mutations as" ${PWD}/${dir}/template_log.txt; then
      echo "    [MUTATION] FAIL: Failed. Exiting script."
      exit 1
    fi

    # Check if the script failed
    if [ $exit_status -ne 0 ]; then
      echo "    [MUTATION] FAIL: I2S_slave failed!"
    else
      echo "    [MUTATION] PASS: I2S_slave passed!"
    fi
  else
    echo "    [MUTATION] ERROR: No run.sh found in $dir"
  fi
done