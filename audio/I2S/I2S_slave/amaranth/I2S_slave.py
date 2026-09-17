# Disable pylint's "your name is too short" warning.
# pylint: disable=C0103from amaranth import *
from amaranth.lib import wiring
from amaranth.lib.wiring import In, Out
from amaranth.sim import Simulator, Period
from amaranth.back import verilog
from typing import List, Tuple
from amaranth import Signal, Module, Elaboratable, ClockSignal, ResetSignal, ClockDomain
from amaranth.build import Platform
# from amaranth.asserts import Past, Initial, Rose
from amaranth.hdl import Assume, Assert, Cover
from util import main


###############
# Main module #
###############
class I2S_slave(wiring.Component):
    """
    A 16-bit up counter with a fixed limit.

    Parameters
    ----------
    limit : int
        The value at which the counter overflows.

    Attributes
    ----------
    en : Signal, in
        The counter is incremented if ``en`` is asserted, and retains
        its value otherwise.
    ovf : Signal, out
        ``ovf`` is asserted when the counter reaches its limit.
    """

    en: In(1)
    ovf: Out(1)

    def __init__(self, limit):
        self.limit = limit
        self.count = Signal(16, name="count") # Added name for clarity in traces/formal

        super().__init__()

    def elaborate(self, platform):
        m = Module()

        m.d.comb += self.ovf.eq(self.count == self.limit)

        with m.If(self.en):
            with m.If(self.ovf):
                m.d.sync += self.count.eq(0)
            with m.Else():
                m.d.sync += self.count.eq(self.count + 1)
        
        # --- Native Manta Logic Analyzer Integration (Optional) ---
        # To enable, uncomment the code below. Install manta first: pip install manta-fpga
        #
        # if platform is not None:
        #     from manta import Manta, LogicAnalyzer, UartTransport
        #
        #     # 1. Instantiate the logic analyzer core to probe internal signals
        #     la = LogicAnalyzer(depth=1024, probes=[
        #         self.en,
        #         self.count,
        #         self.ovf
        #     ])
        #
        #     # 2. Get UART pins defined by the board platform
        #     uart_pins = platform.request("uart", 0)
        #
        #     # 3. Add the Manta core as a submodule with UART transport bridge
        #     m.submodules.manta = Manta(
        #         cores=[la],
        #         transport=UartTransport(pins=uart_pins, baudrate=115200)
        #     )
        
        return m

    @classmethod
    def formal(cls) -> Tuple[Module, List[Signal]]:
        """Formal verification for the I2S_slave module."""
        m = Module()
        # Instantiate your module with a specific limit for formal verification
        m.submodules.I2S_slave = I2S_slave = cls(limit=16)

        # --- Formal Properties ---

        m.d.comb += Cover(I2S_slave.count == 0)
        m.d.comb += Cover(I2S_slave.count == I2S_slave.limit)
        m.d.comb += Cover(I2S_slave.ovf == 1)

        # Return the module 'm' (which contains 'c' as a submodule)
        # and the ports of your counter module 'c'.
        return m, [I2S_slave.en, I2S_slave.count, I2S_slave.ovf]

    
##############
# Simulation #
##############
# --- TEST ---
dut = I2S_slave(25)
async def bench(ctx):
    # Disabled counter should not overflow.
    ctx.set(dut.en, 0)
    for _ in range(30):
        await ctx.tick()
        assert not ctx.get(dut.ovf)

    # Once enabled, the counter should overflow in 25 cycles.
    ctx.set(dut.en, 1)
    for _ in range(24):
        await ctx.tick()
        assert not ctx.get(dut.ovf)
    await ctx.tick()
    assert ctx.get(dut.ovf)

    # The overflow should clear in one cycle.
    await ctx.tick()
    assert not ctx.get(dut.ovf)
    
sim = Simulator(dut)
sim.add_clock(Period(MHz=1))
sim.add_testbench(bench)
with sim.write_vcd("I2S_slave.vcd"):
    sim.run()

##############
# Conversion #
##############
# --- CONVERT ---
top = I2S_slave(25)
with open("I2S_slave.v", "w") as f:
    f.write(verilog.convert(top))

########
# main #
########
if __name__ == "__main__":
    main(I2S_slave)