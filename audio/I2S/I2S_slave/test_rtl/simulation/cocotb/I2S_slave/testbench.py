import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_template(dut):
    """Empty testbench that simply prints PASS."""
    await Timer(1, unit="ns")  # Wait for a small amount of time
    dut._log.info("PASS")