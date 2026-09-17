# I2S_slave Module

This Verilog module implements...

## Features

* Feature1
* Feature2
* Feature3

## Usage

1. **Instantiate the module:**

   ```verilog
   I2S_slave #(
       // Optional parameters here 
   ) I2S_slave (
       .clk(clk),           // Input
       .reset_n(reset_n),   // Input - active low
       .data_in(data_in),   // Input
       .data_out(data_out)  // Output
   );
   ```

## FPGA Debugging with Manta Logic Analyzer

This I2S_slave includes built-in support for the [Manta FPGA Logic Analyzer](https://github.com/fischermoseley/manta).

### Setup (Host Machine)
1. Install Manta Python package:
   ```bash
   pip install manta-fpga
   ```

### Option A: Verilog Workflow
1. Generate the Verilog module for the logic analyzer defined in `manta.yaml`:
   ```bash
   manta gen manta.yaml manta_core.v
   ```
2. Add `manta_core.v` to your synthesis project file list (e.g. `.gprj` file).
3. Uncomment the `manta` module instantiation in `src/top.v` and map the physical UART RX/TX pins to the board pins.
4. Synthesize the project, upload it to the board, and run the host script to capture waveforms:
   ```bash
   python python/manta_test.py --port COM3  # Or your platform serial port
   ```

### Option B: Amaranth Workflow
1. Uncomment the native Manta integration code block inside `amaranth/I2S_slave.py`'s `elaborate` function.
2. Build and flash using Amaranth.