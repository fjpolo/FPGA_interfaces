#!/bin/bash

# Source the OSS CAD Suite environment
echo "        [SBY] Sourcing OSS CAD Suite environment..."
source ~/oss-cad-suite/environment
if [ $? -ne 0 ]; then
    echo "        [SBY] Failed to source OSS CAD Suite environment. Exiting script."
    exit 1
fi

# Input files
ORIGINAL_FILE="${PWD}/../../../rtl/I2S_slave.v"
FORMAL_FILE="properties.v"
CONFIG_FILE="I2S_slave.sby"

# Generate a timestamp for the temporary file
TEMP_FILE="template_formal.v"
echo -n > $TEMP_FILE

# Check if required files exist
echo "        [SBY] Checking if required files exist..."
for FILE in "$ORIGINAL_FILE" "$FORMAL_FILE"; do
    if [ ! -f "$FILE" ]; then
        echo "        [SBY] ERROR: File $FILE not found. Exiting script."
        exit 1
    fi
done

# Insert formal properties into the original master.v before `endmodule`
OS=$(uname -s)

if [[ "$OS" == "Darwin" ]]; then
  # macOS (iOS)
  gsed "/endmodule/e cat $FORMAL_FILE" "$ORIGINAL_FILE" > "$TEMP_FILE"
elif [[ "$OS" == "Linux" ]]; then
  # Linux
  awk -v f_file="$FORMAL_FILE" '/endmodule/{system("cat " f_file); print; next}1' "$ORIGINAL_FILE" > "$TEMP_FILE"
else
  echo "        [SBY] ERROR: Unsupported OS"
  exit 1
fi


# Verify the original master.v with formal properties
# Run SymbiYosys (sby) on the temporary file
echo "        [SBY] Verifying $ORIGINAL_FILE with formal properties..."
CONFIG_FILE="I2S_slave.sby"
sby -f $CONFIG_FILE

# Check if sby succeeded
if [ $? -ne 0 ]; then
    echo "        [SBY] FAIL: sby failed for $ORIGINAL_FILE. Exiting script."
    rm $TEMP_FILE
    exit 1
fi

# Pass
echo ""

# Clean up the temporary file for the original master.v
rm $TEMP_FILE

