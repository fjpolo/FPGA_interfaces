import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from pyuvm import *
import random

class DataTransaction(uvm_sequence_item):
    def __init__(self, name="data_tr"):
        super().__init__(name)
        self.data = 0
        self.result = None

    def randomize(self):
        self.data = random.randint(0, 255)

    def __eq__(self, other):
        return self.data == other.data

    def __str__(self):
        return f"{self.get_name()} : Data: 0x{self.data:02x}"

class TemplateDriver(uvm_driver):
    def start_of_simulation_phase(self):
        self.dut = cocotb.top
        
    async def run_phase(self):
        while True:
            item = await self.seq_item_port.get_next_item()
            self.dut.i_data.value = item.data
            await RisingEdge(self.dut.i_clk)  # Wait for clock edge
            await FallingEdge(self.dut.i_clk)  # Wait for output to stabilize
            item.result = int(self.dut.o_data.value)
            self.seq_item_port.item_done()

class TemplateMonitor(uvm_monitor):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        
    async def run_phase(self):
        dut = cocotb.top
        while True:
            await RisingEdge(dut.i_clk)
            if dut.i_reset_n.value:
                tr = DataTransaction()
                tr.data = int(dut.i_data.value)
                await FallingEdge(dut.i_clk)  # Sample output after clock edge
                tr.result = int(dut.o_data.value)
                self.ap.write(tr)

class TemplateAgent(uvm_agent):
    def build_phase(self):
        self.monitor = TemplateMonitor.create("monitor", self)
        self.driver = TemplateDriver.create("driver", self)
        self.sequencer = uvm_sequencer("sequencer", self)
        
    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sequencer.seq_item_export)

class TemplateScoreboard(uvm_scoreboard):
    def build_phase(self):
        self.fifo = uvm_tlm_analysis_fifo("fifo", self)
        self.analysis_export = self.fifo.analysis_export
        
    def check_phase(self):
        while self.fifo.can_get():
            _, tr = self.fifo.try_get()
            if tr.data != tr.result:
                self.logger.error(f"Data mismatch! Input: 0x{tr.data:02x}, Output: 0x{tr.result:02x}")
                assert False, "Output does not match input"
            else:
                self.logger.info(f"Match! Input: 0x{tr.data:02x}, Output: 0x{tr.result:02x}")

class TemplateEnv(uvm_env):
    def build_phase(self):
        self.agent = TemplateAgent.create("agent", self)
        self.scoreboard = TemplateScoreboard.create("scoreboard", self)
        
    def connect_phase(self):
        self.agent.monitor.ap.connect(self.scoreboard.analysis_export)

class RandomSequence(uvm_sequence):
    async def body(self):
        for _ in range(10):
            tr = DataTransaction()
            await self.start_item(tr)
            tr.randomize()
            await self.finish_item(tr)

class TemplateTest(uvm_test):
    def build_phase(self):
        self.env = TemplateEnv.create("env", self)
        
    async def run_phase(self):
        self.raise_objection()
        dut = cocotb.top
        
        # Initialize clock and reset
        cocotb.start_soon(Clock(dut.i_clk, 10, "ns").start())
        dut.i_reset_n.value = 0
        dut.i_data.value = 0
        await ClockCycles(dut.i_clk, 5)
        dut.i_reset_n.value = 1
        await ClockCycles(dut.i_clk, 2)  # Wait 2 cycles after reset
        
        # Run test
        seq = RandomSequence("random_seq")
        await seq.start(self.env.agent.sequencer)
        
        # Wait for completion
        await ClockCycles(dut.i_clk, 10)
        self.drop_objection()

@cocotb.test()
async def run_test(dut):
    await uvm_root().run_test("TemplateTest")