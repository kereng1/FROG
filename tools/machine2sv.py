#!/usr/bin/env python3
"""
Machine Code to SystemVerilog Memory File Converter
Converts assembler output to $readmemh-compatible format.

Generates TWO formats:
  - Byte format (for RTL byte-organized memory): inst_mem.sv, data_mem.sv
  - Word format (for REF word-organized memory): inst_mem_word.sv, data_mem_word.sv

Usage:
    python machine2sv.py <input.txt> [-o output_dir]

Input format (from assembler):
    <address>: <instruction_hex>
    00000000: 00A00093
    00000004: 01400113
"""

import argparse
import sys
import re
import os
from datetime import datetime


def convert_to_words(input_lines):
    """
    Convert assembler output lines to list of 32-bit words.
    
    Args:
        input_lines: List of lines in "address: hex" format
        
    Returns:
        List of 32-bit hex word strings (uppercase)
    """
    words = []
    
    for line_num, line in enumerate(input_lines, 1):
        # Remove comments
        if '#' in line:
            line = line[:line.index('#')]
        if '//' in line:
            line = line[:line.index('//')]
        
        line = line.strip()
        
        # Skip empty lines
        if not line:
            continue
        
        # Parse "address: hex" format
        match = re.match(r'^(?:0x)?([0-9A-Fa-f]+)\s*:\s*(?:0x)?([0-9A-Fa-f]+)', line)
        
        if match:
            hex_instr = match.group(2).upper().zfill(8)
            words.append(hex_instr)
        else:
            # Try to parse just a hex value
            hex_match = re.match(r'^(?:0x)?([0-9A-Fa-f]{8})$', line)
            if hex_match:
                words.append(hex_match.group(1).upper())
            else:
                print(f"Warning: Line {line_num}: Could not parse: {line}", file=sys.stderr)
    
    return words


def word_to_bytes_le(word):
    """
    Convert a 32-bit word string to list of byte strings (little-endian).
    
    Args:
        word: 8-char hex string like "00A00093"
        
    Returns:
        List of 4 byte strings in little-endian order: ["93", "00", "A0", "00"]
    """
    # word[6:8] is LSB, word[0:2] is MSB
    return [
        word[6:8],  # byte 0 (LSB)
        word[4:6],  # byte 1
        word[2:4],  # byte 2
        word[0:2],  # byte 3 (MSB)
    ]


def generate_byte_format(words, source_file=None):
    """
    Generate byte-format output (one byte per line, little-endian).
    For RTL byte-organized memory.
    """
    lines = []
    
    # Header
    lines.append("// Memory initialization (byte format, little-endian)")
    lines.append("// For RTL byte-organized memory")
    if source_file:
        lines.append(f"// Source: {source_file}")
    lines.append(f"// Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"// Total instructions: {len(words)} ({len(words)*4} bytes)")
    lines.append("")
    
    # Convert each word to bytes (little-endian)
    for word in words:
        for byte_str in word_to_bytes_le(word):
            lines.append(byte_str)
    
    return '\n'.join(lines)


def generate_word_format(words, source_file=None):
    """
    Generate word-format output (one 32-bit word per line).
    For REF word-organized memory.
    """
    lines = []
    
    # Header
    lines.append("// Memory initialization (word format)")
    lines.append("// For REF word-organized memory")
    if source_file:
        lines.append(f"// Source: {source_file}")
    lines.append(f"// Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"// Total instructions: {len(words)}")
    lines.append("")
    
    # One word per line
    for word in words:
        lines.append(word)
    
    return '\n'.join(lines)


def generate_empty_mem(size_bytes, is_byte_format=True, name="data"):
    """
    Generate empty (zeroed) memory file.
    """
    lines = []
    
    if is_byte_format:
        lines.append(f"// Empty {name} memory (byte format)")
        lines.append(f"// Size: {size_bytes} bytes")
        lines.append(f"// Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("")
        for _ in range(size_bytes):
            lines.append("00")
    else:
        words = size_bytes // 4
        lines.append(f"// Empty {name} memory (word format)")
        lines.append(f"// Size: {words} words")
        lines.append(f"// Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("")
        for _ in range(words):
            lines.append("00000000")
    
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Convert assembler output to SystemVerilog memory files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python machine2sv.py input.txt
    python machine2sv.py input.txt -o output_tools/
    
Generates:
    - inst_mem.sv       (byte format for RTL)
    - inst_mem_word.sv  (word format for REF)
    - data_mem.sv       (byte format for RTL, empty)
    - data_mem_word.sv  (word format for REF, empty)
        """
    )
    parser.add_argument('input', help='Input machine code file (.txt)')
    parser.add_argument('-o', '--output-dir', default='output_tools',
                        help='Output directory (default: output_tools)')
    parser.add_argument('--dmem-size', type=int, default=1024,
                        help='Data memory size in bytes (default: 1024)')
    
    args = parser.parse_args()
    
    # Determine output directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    output_dir = os.path.join(project_root, args.output_dir)
    os.makedirs(output_dir, exist_ok=True)
    
    # Read input file
    try:
        with open(args.input, 'r') as f:
            input_lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading input file: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Convert to words
    words = convert_to_words(input_lines)
    
    if not words:
        print("Warning: No instructions found in input file", file=sys.stderr)
    
    source_name = os.path.basename(args.input)
    
    # Generate instruction memory files
    inst_byte = generate_byte_format(words, source_name)
    inst_word = generate_word_format(words, source_name)
    
    # Generate data memory files (empty)
    data_byte = generate_empty_mem(args.dmem_size, is_byte_format=True, name="data")
    data_word = generate_empty_mem(args.dmem_size, is_byte_format=False, name="data")
    
    # Write files
    files = [
        ('inst_mem.sv', inst_byte),
        ('inst_mem_word.sv', inst_word),
        ('data_mem.sv', data_byte),
        ('data_mem_word.sv', data_word),
    ]
    
    for filename, content in files:
        filepath = os.path.join(output_dir, filename)
        try:
            with open(filepath, 'w') as f:
                f.write(content)
                f.write('\n')
            print(f"Generated: {filepath}")
        except Exception as e:
            print(f"Error writing {filename}: {e}", file=sys.stderr)
            sys.exit(1)
    
    print(f"\nConverted {len(words)} instructions")
    print(f"Output directory: {output_dir}")


if __name__ == "__main__":
    main()
