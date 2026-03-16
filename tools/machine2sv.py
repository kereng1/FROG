#!/usr/bin/env python3
"""
Machine Code to SystemVerilog Memory File Converter
Converts assembler output to $readmemh-compatible format.

Usage:
    python machine2sv.py <input.txt> [-o output.sv]

Input format (from assembler):
    <address>: <instruction_hex>
    00000000: 00A00093
    00000004: 01400113

Output format (for $readmemh):
    // Memory initialization for simulation
    // Generated from machine code
    
    93 00 A0 00 13 01 40 01 ...
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
        List of 32-bit hex word strings
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
        # Matches patterns like:
        #   00000000: 00A00093
        #   0x00000000: 0x00A00093
        match = re.match(r'^(?:0x)?([0-9A-Fa-f]+)\s*:\s*(?:0x)?([0-9A-Fa-f]+)', line)
        
        if match:
            hex_instr = match.group(2).upper().zfill(8)
            words.append(hex_instr)
        else:
            # Try to parse just a hex value (for more flexible input)
            hex_match = re.match(r'^(?:0x)?([0-9A-Fa-f]{8})$', line)
            if hex_match:
                words.append(hex_match.group(1).upper())
            else:
                print(f"Warning: Line {line_num}: Could not parse: {line}", file=sys.stderr)
    
    return words


def format_output(words, source_file=None):
    """
    Format words into output string with header (one word per line for $readmemh).
    
    Args:
        words: List of 32-bit hex word strings
        source_file: Optional source filename for header
        
    Returns:
        Formatted output string
    """
    lines = []
    
    # Header
    lines.append("// Memory initialization for simulation")
    lines.append("// Generated from machine code")
    if source_file:
        lines.append(f"// Source: {source_file}")
    lines.append(f"// Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"// Total instructions: {len(words)}")
    lines.append("")
    
    # One word per line (compatible with $readmemh)
    for word in words:
        lines.append(word)
    
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Convert assembler output to SystemVerilog memory file',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python machine2sv.py test.txt
    python machine2sv.py test.txt -o load_mem.sv
    
Input format:
    00000000: 00A00093
    00000004: 01400113
    
Output format:
    // Memory initialization for simulation
    // Generated from machine code
    
    93 00 A0 00 13 01 40 01
        """
    )
    parser.add_argument('input', help='Input machine code file (.txt)')
    parser.add_argument('-o', '--output', help='Output SV file (default: output_tools/<input>.sv)')
    
    args = parser.parse_args()
    
    # Determine output filename
    if args.output:
        output_file = args.output
    else:
        # Get base name without path and extension
        base_name = os.path.basename(args.input)
        if base_name.endswith('.txt'):
            base_name = base_name[:-4]
        
        # Output to output_tools/ directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(script_dir)
        output_dir = os.path.join(project_root, 'output_tools')
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, base_name + '.sv')
    
    # Ensure output directory exists
    output_dir = os.path.dirname(output_file)
    if output_dir:
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
    
    # Format output
    output_content = format_output(words, os.path.basename(args.input))
    
    # Write output
    try:
        with open(output_file, 'w') as f:
            f.write(output_content)
            f.write('\n')
        print(f"Converted {len(words)} instructions -> {output_file}")
    except Exception as e:
        print(f"Error writing output file: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
