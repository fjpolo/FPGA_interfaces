import os
import shutil
import subprocess
from pathlib import Path

try:
    from cocotb_tools.runner import get_runner
except ImportError:
    from cocotb.runner import get_runner


def test_my_design_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / "I2S_slave.v"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="I2S_slave",
        always=True,
        waves=True,
    )

    runner.test(
        hdl_toplevel="I2S_slave",
        test_module="testbench",
        waves=True,
    )

    # Convert FST waveform to standard VCD for Surfer
    sim_build_dir = proj_path / "sim_build"
    fst_file = sim_build_dir / "I2S_slave.fst"
    vcd_output = proj_path / "I2S_slave.vcd"

    if fst_file.exists():
        fst2vcd_bin = shutil.which("fst2vcd")
        if fst2vcd_bin:
            subprocess.run([fst2vcd_bin, "-o", str(vcd_output), str(fst_file)], check=True)
            print(f"[COCOTB] Waveform VCD exported for Surfer: {vcd_output}")
        else:
            print("[COCOTB] WARNING: fst2vcd not found; keeping FST waveform.")
    elif (sim_build_dir / "I2S_slave.vcd").exists():
        shutil.copy(sim_build_dir / "I2S_slave.vcd", vcd_output)
        print(f"[COCOTB] Waveform VCD exported for Surfer: {vcd_output}")


if __name__ == "__main__":
    test_my_design_runner()