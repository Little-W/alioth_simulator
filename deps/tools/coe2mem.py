import sys
import os

def convert_coe_to_memh(input_file, output_file=None):
    if output_file is None:
        output_file = os.path.splitext(input_file)[0] + ".mem"

    with open(input_file, 'r') as f:
        lines = f.readlines()

    with open(output_file, 'w') as f:
        write_flag = False
        for line in lines:
            line = line.strip()
            if line.startswith("memory_initialization_vector"):
                write_flag = True
                continue
            if write_flag:
                line = line.replace(',', '').replace(';', '')
                if line:
                    f.write(line + '\n')

    print(f"Converted '{input_file}' to '{output_file}'")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_coe_to_memh.py input.coe [output.memh]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    convert_coe_to_memh(input_file, output_file)
