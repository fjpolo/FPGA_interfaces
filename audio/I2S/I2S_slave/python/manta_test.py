#!/usr/bin/env python3
import argparse
import sys
from manta import Manta

def main():
    parser = argparse.ArgumentParser(description="Manta Logic Analyzer Interface")
    parser.add_argument("-p", "--port", type=str, default="auto", help="Serial port of the FPGA board")
    parser.add_argument("-b", "--baud", type=int, default=115200, help="Baudrate of UART connection")
    args = parser.parse_args()

    print(f"Connecting to Manta FPGA core using port={args.port}, baudrate={args.baud}...")
    try:
        # Load the configuration and establish connection
        m = Manta("manta.yaml", port=args.port, baudrate=args.baud)
        
        print("Manta connected successfully!")
        print("Triggering logic analyzer...")
        
        # Trigger logic analyzer core
        m.la_core.trigger()
        
        print("Waiting for buffer to fill...")
        m.la_core.wait_until_done()
        
        # Read the sampled trace buffer
        samples = m.la_core.read_buffer()
        print(f"Captured {len(samples)} samples:")
        
        for i, sample in enumerate(samples[:20]): # Show first 20 samples
            print(f"Sample {i:4d}: reset_n={sample['i_reset_n']} | i_data=0x{sample['i_data']:02X} | o_data=0x{sample['o_data']:02X}")
            
        if len(samples) > 20:
            print("...")
            
    except Exception as e:
        print(f"Error connecting or communicating with Manta core: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
