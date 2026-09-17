#include <iostream>
#include <verilated.h>          // Common Verilator includes
#include <verilated_vcd_c.h>    // For VCD tracing
#include "Vtemplate.h"          // Your Verilated module header

// Define the name of the top module for Verilator
// This matches the `OUTPUT_NAME` in your verilator_runner.sh script (or Makefile)
#define TOP_MODULE_NAME Vtemplate

// Global variables for simulation control
TOP_MODULE_NAME *top;       // Pointer to the Verilated top module
VerilatedVcdC *tfp;         // Pointer to the VCD trace file
vluint64_t main_time = 0;   // Current simulation time (in ps, matching timescale)

// Dummy sc_time_stamp() function to satisfy linker if Verilator's internal
// libraries still reference it even with --no-sc.
// This is required if Verilator was built with SystemC support enabled,
// even if you don't intend to use SystemC in your testbench.
double sc_time_stamp() {
    return (double)main_time; // Return current simulation time
}

// Function to advance simulation time and dump waveforms
void eval_and_dump() {
    top->eval(); // Evaluate the DUT
    if (tfp) {
        tfp->dump(main_time); // Dump waveforms at current time
    }
    main_time++; // Increment simulation time
}

// Main function for the C++ testbench
int main(int argc, char** argv, char** env) {
    // 1. Initialize Verilator
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true); // Enable tracing

    // 2. Instantiate the top-level module
    top = new TOP_MODULE_NAME;

    // 3. Setup VCD tracing
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99); // Trace all signals up to depth 99
    tfp->open("dump.vcd"); // Open the VCD file (matches WAVEFORM in script)

    // Initial values for inputs
    top->i_clk     = 0;
    top->i_reset_n = 0; // Assert reset initially
    top->i_data    = 0x00;

    // --- Simulation Test Sequence ---

    // Apply initial reset for a few clock cycles
    std::cout << "        [TB] Applying reset..." << std::endl;
    for (int i = 0; i < 10; ++i) { // Simulate for 10 time steps (5 clock cycles)
        if (i == 5) { // De-assert reset after 5 time steps (2.5 clock cycles)
            top->i_reset_n = 1;
        }
        top->i_clk = !top->i_clk; // Toggle clock
        eval_and_dump();          // Evaluate and dump
    }

    // Verify reset behavior
    if (top->o_data != 0x00) {
        std::cerr << "        [TB] ERROR: o_data not 0x00 after reset. Got: "
                  << std::hex << (int)top->o_data << std::dec << std::endl;
        // Optionally, you can call Verilated::gotFinish() to exit with an error code
        // Verilated::gotFinish(1);
    } else {
        std::cout << "        [TB] o_data is 0x00 after reset. PASS." << std::endl;
    }


    // Test data propagation
    std::cout << "        [TB] Testing data propagation..." << std::endl;
    vluint8_t test_data[] = {0xAA, 0x55, 0xF0, 0x0F};
    for (int i = 0; i < sizeof(test_data); ++i) {
        top->i_data = test_data[i];
        std::cout << "        [TB] Input i_data = 0x" << std::hex << (int)top->i_data << std::dec << std::endl;

        // Toggle clock for one full cycle to propagate data
        top->i_clk = !top->i_clk; // Rising edge
        eval_and_dump();
        top->i_clk = !top->i_clk; // Falling edge
        eval_and_dump();

        // Check output after a full clock cycle
        if (top->o_data != test_data[i]) {
            std::cerr << "        [TB] ERROR: o_data mismatch for 0x" << std::hex << (int)test_data[i]
                      << ". Expected: 0x" << (int)test_data[i] << ", Got: 0x" << (int)top->o_data << std::dec << std::endl;
            // Verilated::gotFinish(1);
        } else {
            std::cout << "        [TB] o_data matches for 0x" << std::hex << (int)test_data[i] << ". PASS." << std::dec << std::endl;
        }
    }

    // Run for a few more cycles to observe signals
    std::cout << "        [TB] Running for a few more cycles to observe waveforms..." << std::endl;
    for (int i = 0; i < 20; ++i) {
        top->i_clk = !top->i_clk;
        eval_and_dump();
    }


    // --- Simulation Teardown ---
    std::cout << "        [TB] Simulation finished." << std::endl;
    if (tfp) {
        tfp->close();    // Close the VCD file
        delete tfp;      // Delete the trace pointer
    }
    delete top;          // Delete the Verilated module instance
    Verilated::flushCall(); // Flush any pending output
    Verilated::gotFinish(); // Signal completion to Verilator
    return 0;
}
