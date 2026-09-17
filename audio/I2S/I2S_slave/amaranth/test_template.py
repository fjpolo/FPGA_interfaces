import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

@cocotb.test()
async def counter_test(dut):
    """Test the 16-bit up counter with a fixed limit."""

    # Define the limit value used in the Amaranth design
    # This must match the 'limit' passed to I2S_slave() in I2S_slave.py's conversion section
    LIMIT_VAL = 25

    # Create a clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Initial state: wait for a few clock cycles to ensure stable state after simulation start
    await ClockCycles(dut.clk, 5) # Added a few initial cycles for stability

    # Disabled counter should not overflow.
    dut.en.value = 0 # Set enable to 0
    await RisingEdge(dut.clk) # Wait for changes to propagate

    for i in range(LIMIT_VAL + 5): # Loop longer than limit to confirm no ovf when disabled
        assert dut.ovf.value == 0, f"Error: ovf asserted at cycle {i} when disabled. Count was {dut.count.value if hasattr(dut, 'count') else 'N/A'}."
        await RisingEdge(dut.clk)

    # Once enabled, the counter should overflow at LIMIT_VAL.
    # Since the counter starts at 0, it will reach LIMIT_VAL after LIMIT_VAL increments.
    dut.en.value = 1
    await RisingEdge(dut.clk) # Wait for enable to propagate

    # Count up to (LIMIT_VAL - 1)
    for i in range(LIMIT_VAL - 1):
        assert dut.ovf.value == 0, f"Error: ovf asserted early at count {i}."
        await RisingEdge(dut.clk)

    # At this point, count should be (LIMIT_VAL - 1).
    # On the next rising edge, it increments to 'LIMIT_VAL', and ovf should assert (combinational).
    assert dut.ovf.value == 0, "Error: ovf asserted too early before reaching limit."
    await RisingEdge(dut.clk) # Counter increments to 'LIMIT_VAL'
    assert dut.ovf.value == 1, f"Error: ovf did not assert when count reached limit. Current count: {dut.count.value if hasattr(dut, 'count') else 'N/A'}"

    # The overflow should clear in one cycle (as count goes back to 0).
    await RisingEdge(dut.clk)
    assert dut.ovf.value == 0, "Error: ovf did not deassert after overflow."
    # If you want to check the count, inspect your I2S_slave.v for the exact path:
    # Example: if your Amaranth module instance inside 'top' is named '_design',
    # and count is an internal signal, it might be dut._design.count.value
    # For a simple I2S_slave, dut.count.value *might* work, depending on Verilator's flattening.
    # For now, we'll stick to 'ovf' as it's a top-level port.

    cocotb.log.info("Cocotb test finished successfully!")