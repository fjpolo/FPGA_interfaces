import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

CLK_PERIOD_NS = 10      # 100 MHz FPGA system clock
SCK_PERIOD_NS = 80      # 12.5 MHz I2S serial clock (8x i_clk cycles)
DATA_WIDTH = 24
SLOT_WIDTH = 32         # 32 bit clocks per channel slot (standard Philips I2S)


class I2SMasterBfm:
    """Emulates external Philips I2S Master bus (driving i_sck, i_ws, i_sd)."""

    def __init__(self, dut, sck_period_ns=SCK_PERIOD_NS, slot_width=SLOT_WIDTH, data_width=DATA_WIDTH):
        self.dut = dut
        self.sck_period_ns = sck_period_ns
        self.half_sck_ns = sck_period_ns // 2
        self.slot_width = slot_width
        self.data_width = data_width

    async def sck_half_period(self):
        await Timer(self.half_sck_ns, unit="ns")

    async def send_stereo_frame(self, data_l, data_r):
        """Sends one 2-channel I2S frame (Left: WS=0, Right: WS=1) with 1-SCK delay."""
        channels = [
            (0, data_l),  # WS = 0 is Left channel
            (1, data_r),  # WS = 1 is Right channel
        ]

        for ws_val, sample in channels:
            # WS changes on SCK falling edge
            self.dut.i_ws.value = ws_val
            # First SCK cycle after WS transition is the 1-cycle delay slot
            self.dut.i_sd.value = 0
            await self.sck_half_period()  # SCK Low
            self.dut.i_sck.value = 1
            await self.sck_half_period()  # SCK High (Delay slot sampled)
            self.dut.i_sck.value = 0

            # Transmit DATA_WIDTH bits (MSB first)
            for bit_idx in range(self.data_width - 1, -1, -1):
                bit = (sample >> bit_idx) & 1
                self.dut.i_sd.value = bit
                await self.sck_half_period()  # SCK Low
                self.dut.i_sck.value = 1
                await self.sck_half_period()  # SCK High
                self.dut.i_sck.value = 0

            # Remaining padding cycles in the slot (e.g. 32 - 24 - 1 = 7 cycles)
            padding_cycles = self.slot_width - self.data_width - 1
            for _ in range(padding_cycles):
                self.dut.i_sd.value = 0
                await self.sck_half_period()  # SCK Low
                self.dut.i_sck.value = 1
                await self.sck_half_period()  # SCK High
                self.dut.i_sck.value = 0


async def host_tx_driver(dut, tx_queue):
    """Responds to o_tx_ready by providing the next stereo sample pair."""
    while True:
        await RisingEdge(dut.i_clk)
        if dut.o_tx_ready.value == 1:
            if len(tx_queue) > 0:
                l_val, r_val = tx_queue.pop(0)
                dut.i_tx_data_l.value = l_val
                dut.i_tx_data_r.value = r_val
                dut.i_tx_valid.value = 1
                # Wait for next rising edge so DUT registers data and lowers o_tx_ready
                await RisingEdge(dut.i_clk)
                dut.i_tx_valid.value = 0
            else:
                dut.i_tx_valid.value = 0
        else:
            dut.i_tx_valid.value = 0


async def reset_dut(dut):
    """Applies active-low reset to DUT."""
    dut.i_reset_n.value = 0
    dut.i_sck.value = 0
    dut.i_ws.value = 0       # Idle in Left channel state
    dut.i_sd.value = 0
    dut.i_tx_data_l.value = 0
    dut.i_tx_data_r.value = 0
    dut.i_tx_valid.value = 0
    await ClockCycles(dut.i_clk, 10)
    dut.i_reset_n.value = 1
    await ClockCycles(dut.i_clk, 5)


@cocotb.test()
async def test_reset_and_defaults(dut):
    """Verify default output values after reset."""
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    assert dut.o_sd.value == 0, f"o_sd expected 0, got {dut.o_sd.value}"
    assert dut.o_rx_data_l.value == 0, f"o_rx_data_l expected 0, got {dut.o_rx_data_l.value}"
    assert dut.o_rx_data_r.value == 0, f"o_rx_data_r expected 0, got {dut.o_rx_data_r.value}"
    assert dut.o_rx_valid.value == 0, f"o_rx_valid expected 0, got {dut.o_rx_valid.value}"
    assert dut.o_tx_ready.value == 0, f"o_tx_ready expected 0, got {dut.o_tx_ready.value}"
    assert dut.o_channel_sync.value == 0, f"o_channel_sync expected 0, got {dut.o_channel_sync.value}"
    dut._log.info("[PASS] Reset state validated successfully.")


@cocotb.test()
async def test_slave_rx_single_frame(dut):
    """Test reception of a single stereo audio frame (Left & Right channels)."""
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    bfm = I2SMasterBfm(dut)

    exp_l = 0xA5A5A5
    exp_r = 0x5A5A5A

    rx_captured = []

    async def monitor_rx():
        while len(rx_captured) < 1:
            await RisingEdge(dut.i_clk)
            if dut.o_rx_valid.value == 1:
                rx_captured.append((int(dut.o_rx_data_l.value), int(dut.o_rx_data_r.value)))

    cocotb.start_soon(monitor_rx())

    # Send first frame
    await bfm.send_stereo_frame(exp_l, exp_r)

    # Transition to Left to trigger the end of the frame (o_rx_valid pulse)
    dut.i_ws.value = 0
    await bfm.sck_half_period()
    dut.i_sck.value = 1
    await bfm.sck_half_period()
    dut.i_sck.value = 0

    await ClockCycles(dut.i_clk, 20)

    assert len(rx_captured) == 1, f"Expected 1 RX frame, captured {len(rx_captured)}"
    act_l, act_r = rx_captured[0]
    assert act_l == exp_l, f"Left channel mismatch! Expected 0x{exp_l:06X}, got 0x{act_l:06X}"
    assert act_r == exp_r, f"Right channel mismatch! Expected 0x{exp_r:06X}, got 0x{act_r:06X}"
    dut._log.info(f"[PASS] Single frame RX verified: L=0x{act_l:06X}, R=0x{act_r:06X}")


@cocotb.test()
async def test_full_duplex_multi_frame(dut):
    """Verify simultaneous full-duplex transmission and reception across multiple frames."""
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    bfm = I2SMasterBfm(dut)

    # Test frames to send into Slave RX
    rx_test_vectors = [
        (0x123456, 0x654321),
        (0x7FFFFF, 0x800000),  # Extreme values: max positive, max negative
        (0xAAAAAA, 0x555555),
        (0x000001, 0xFFFFFE),
        (0xFEDCBA, 0x012345),
    ]

    # Test frames for Slave TX
    tx_test_vectors = [
        (0x112233, 0x445566),
        (0x778899, 0xAABBCC),
        (0xDDEEFF, 0x001122),
        (0x334455, 0x667788),
        (0x99AABB, 0xCCDDEE),
        (0x13579B, 0x2468AC),
    ]

    tx_queue = list(tx_test_vectors)
    cocotb.start_soon(host_tx_driver(dut, tx_queue))

    captured_rx_frames = []

    async def rx_monitor():
        while len(captured_rx_frames) < len(rx_test_vectors):
            await RisingEdge(dut.i_clk)
            if dut.o_rx_valid.value == 1:
                l_val = int(dut.o_rx_data_l.value)
                r_val = int(dut.o_rx_data_r.value)
                captured_rx_frames.append((l_val, r_val))
                dut._log.info(f"Captured RX Frame {len(captured_rx_frames)}: L=0x{l_val:06X}, R=0x{r_val:06X}")

    cocotb.start_soon(rx_monitor())

    # Send all test frames over the external bus
    for idx, (exp_l, exp_r) in enumerate(rx_test_vectors):
        dut._log.info(f"Transmitting external frame {idx+1}: L=0x{exp_l:06X}, R=0x{exp_r:06X}")
        await bfm.send_stereo_frame(exp_l, exp_r)

    # Transition to Left to trigger the final o_rx_valid pulse
    dut.i_ws.value = 0
    await bfm.sck_half_period()
    dut.i_sck.value = 1
    await bfm.sck_half_period()
    dut.i_sck.value = 0

    await ClockCycles(dut.i_clk, 40)

    # Verify all received frames match
    assert len(captured_rx_frames) == len(rx_test_vectors), \
        f"Expected {len(rx_test_vectors)} RX frames, captured {len(captured_rx_frames)}"

    for i, ((exp_l, exp_r), (act_l, act_r)) in enumerate(zip(rx_test_vectors, captured_rx_frames)):
        assert act_l == exp_l, f"Frame {i+1} Left mismatch: expected 0x{exp_l:06X}, got 0x{act_l:06X}"
        assert act_r == exp_r, f"Frame {i+1} Right mismatch: expected 0x{exp_r:06X}, got 0x{act_r:06X}"

    dut._log.info(f"[PASS] All {len(rx_test_vectors)} full-duplex frames successfully verified!")


@cocotb.test()
async def test_slave_tx_bitstream(dut):
    """Verify that o_sd bitstream strictly follows Philips 1-SCK delay and MSB-first serial order."""
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    bfm = I2SMasterBfm(dut)

    tx_l = 0x89ABCD
    tx_r = 0x456789

    tx_queue = [(tx_l, tx_r), (tx_l, tx_r), (0, 0)]
    cocotb.start_soon(host_tx_driver(dut, tx_queue))

    # Send frame 1: triggers o_tx_ready on transition from Right to Left at end of frame 1
    await bfm.send_stereo_frame(0, 0)
    # Send frame 2: latches active registers at start of frame 2
    await bfm.send_stereo_frame(0, 0)

    # Now on frame 3, slave outputs tx_l and tx_r on o_sd!
    captured_tx_l_bits = []
    captured_tx_r_bits = []

    # Left Channel (WS = 0)
    dut.i_ws.value = 0
    # 1-SCK delay slot
    await bfm.sck_half_period()
    dut.i_sck.value = 1
    await bfm.sck_half_period()
    dut.i_sck.value = 0

    # Data cycles: Sample bits on SCK High
    for _ in range(DATA_WIDTH):
        await bfm.sck_half_period()
        dut.i_sck.value = 1
        await Timer(1, unit="ns")
        captured_tx_l_bits.append(int(dut.o_sd.value))
        await Timer(bfm.half_sck_ns - 1, unit="ns")
        dut.i_sck.value = 0

    # Padding cycles in Left slot
    for _ in range(SLOT_WIDTH - DATA_WIDTH - 1):
        await bfm.sck_half_period()
        dut.i_sck.value = 1
        await bfm.sck_half_period()
        dut.i_sck.value = 0

    # Right Channel (WS = 1)
    dut.i_ws.value = 1
    # 1-SCK delay slot
    await bfm.sck_half_period()
    dut.i_sck.value = 1
    await bfm.sck_half_period()
    dut.i_sck.value = 0

    # Data cycles: Sample bits on SCK High
    for _ in range(DATA_WIDTH):
        await bfm.sck_half_period()
        dut.i_sck.value = 1
        await Timer(1, unit="ns")
        captured_tx_r_bits.append(int(dut.o_sd.value))
        await Timer(bfm.half_sck_ns - 1, unit="ns")
        dut.i_sck.value = 0

    # Padding cycles in Right slot
    for _ in range(SLOT_WIDTH - DATA_WIDTH - 1):
        await bfm.sck_half_period()
        dut.i_sck.value = 1
        await bfm.sck_half_period()
        dut.i_sck.value = 0

    # Reconstruct 24-bit words from captured bit arrays
    act_tx_l = 0
    for b in captured_tx_l_bits:
        act_tx_l = (act_tx_l << 1) | b

    act_tx_r = 0
    for b in captured_tx_r_bits:
        act_tx_r = (act_tx_r << 1) | b

    dut._log.info(f"Captured Slave TX: Left=0x{act_tx_l:06X}, Right=0x{act_tx_r:06X}")
    assert act_tx_l == tx_l, f"Slave TX Left mismatch! Expected 0x{tx_l:06X}, got 0x{act_tx_l:06X}"
    assert act_tx_r == tx_r, f"Slave TX Right mismatch! Expected 0x{tx_r:06X}, got 0x{act_tx_r:06X}"
    dut._log.info("[PASS] Slave TX serial bitstream compliance verified successfully.")


@cocotb.test()
async def test_channel_sync_pulse(dut):
    """Verify that o_channel_sync pulses exactly once for 1 clock cycle on each WS transition."""
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await reset_dut(dut)

    bfm = I2SMasterBfm(dut)

    sync_pulse_count = 0

    async def sync_monitor():
        nonlocal sync_pulse_count
        while True:
            await RisingEdge(dut.i_clk)
            if dut.o_channel_sync.value == 1:
                sync_pulse_count += 1

    cocotb.start_soon(sync_monitor())

    # Send 2 stereo frames (4 WS transitions: 0 -> 1 -> 0 -> 1)
    await bfm.send_stereo_frame(0x111111, 0x222222)
    await bfm.send_stereo_frame(0x333333, 0x444444)

    # 1 extra transition back to 0
    dut.i_ws.value = 0
    await bfm.sck_half_period()
    dut.i_sck.value = 1
    await bfm.sck_half_period()
    dut.i_sck.value = 0

    await ClockCycles(dut.i_clk, 20)

    # Total WS transitions: frame 1 (WS=0->1, 1 edge) -> frame 2 (WS=0, WS=1, 2 edges) -> extra WS=0 = 4 edges
    assert sync_pulse_count == 4, f"Expected 4 sync pulses, but counted {sync_pulse_count}"
    dut._log.info(f"[PASS] Channel sync pulses validated: exactly {sync_pulse_count} pulses for 4 WS transitions.")