#!/usr/bin/env python3
"""
RISC-V RV32I Assembler
Converts assembly source files to human-readable machine code format.

Usage:
    python assembler.py <input.asm> [-o output.txt]

Output format:
    <address>: <instruction_hex>
"""

import argparse
import sys
import re

# =============================================================================
# Register Definitions
# =============================================================================

# ABI register names to register numbers
REG_ALIASES = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7,
    's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
    's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23,
    's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}

def parse_register(reg_str):
    """Parse register string (x0-x31 or ABI name) to register number."""
    reg_str = reg_str.strip().lower()
    
    # Check for x0-x31 format
    if reg_str.startswith('x'):
        try:
            num = int(reg_str[1:])
            if 0 <= num <= 31:
                return num
        except ValueError:
            pass
    
    # Check for ABI name
    if reg_str in REG_ALIASES:
        return REG_ALIASES[reg_str]
    
    raise ValueError(f"Invalid register: {reg_str}")

# =============================================================================
# Instruction Encoding Tables
# =============================================================================

# R-type instructions: {mnemonic: (funct7, funct3)}
R_TYPE = {
    'add':  (0b0000000, 0b000),
    'sub':  (0b0100000, 0b000),
    'sll':  (0b0000000, 0b001),
    'slt':  (0b0000000, 0b010),
    'sltu': (0b0000000, 0b011),
    'xor':  (0b0000000, 0b100),
    'srl':  (0b0000000, 0b101),
    'sra':  (0b0100000, 0b101),
    'or':   (0b0000000, 0b110),
    'and':  (0b0000000, 0b111),
}

# I-type ALU instructions: {mnemonic: funct3}
I_TYPE_ALU = {
    'addi':  0b000,
    'slti':  0b010,
    'sltiu': 0b011,
    'xori':  0b100,
    'ori':   0b110,
    'andi':  0b111,
}

# I-type shift instructions: {mnemonic: (funct7, funct3)}
I_TYPE_SHIFT = {
    'slli': (0b0000000, 0b001),
    'srli': (0b0000000, 0b101),
    'srai': (0b0100000, 0b101),
}

# Load instructions: {mnemonic: funct3}
LOAD_TYPE = {
    'lb':  0b000,
    'lh':  0b001,
    'lw':  0b010,
    'lbu': 0b100,
    'lhu': 0b101,
}

# Store instructions: {mnemonic: funct3}
STORE_TYPE = {
    'sb': 0b000,
    'sh': 0b001,
    'sw': 0b010,
}

# Branch instructions: {mnemonic: funct3}
BRANCH_TYPE = {
    'beq':  0b000,
    'bne':  0b001,
    'blt':  0b100,
    'bge':  0b101,
    'bltu': 0b110,
    'bgeu': 0b111,
}

# Opcodes
OPCODE_R      = 0b0110011
OPCODE_I_ALU  = 0b0010011
OPCODE_LOAD   = 0b0000011
OPCODE_STORE  = 0b0100011
OPCODE_BRANCH = 0b1100011
OPCODE_JAL    = 0b1101111
OPCODE_JALR   = 0b1100111
OPCODE_LUI    = 0b0110111
OPCODE_AUIPC  = 0b0010111

# =============================================================================
# Instruction Encoding Functions
# =============================================================================

def encode_r_type(rd, rs1, rs2, funct3, funct7):
    """Encode R-type instruction."""
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | OPCODE_R

def encode_i_type(rd, rs1, imm, funct3, opcode):
    """Encode I-type instruction."""
    imm = imm & 0xFFF  # 12-bit immediate
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i_type_shift(rd, rs1, shamt, funct3, funct7):
    """Encode I-type shift instruction."""
    shamt = shamt & 0x1F  # 5-bit shift amount
    return (funct7 << 25) | (shamt << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | OPCODE_I_ALU

def encode_s_type(rs1, rs2, imm, funct3):
    """Encode S-type instruction."""
    imm = imm & 0xFFF
    imm_11_5 = (imm >> 5) & 0x7F
    imm_4_0 = imm & 0x1F
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | OPCODE_STORE

def encode_b_type(rs1, rs2, imm, funct3):
    """Encode B-type instruction."""
    imm = imm & 0x1FFF  # 13-bit immediate (bit 0 always 0)
    imm_12 = (imm >> 12) & 0x1
    imm_11 = (imm >> 11) & 0x1
    imm_10_5 = (imm >> 5) & 0x3F
    imm_4_1 = (imm >> 1) & 0xF
    return (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | OPCODE_BRANCH

def encode_u_type(rd, imm, opcode):
    """Encode U-type instruction (LUI, AUIPC)."""
    imm = imm & 0xFFFFF  # 20-bit immediate
    return (imm << 12) | (rd << 7) | opcode

def encode_j_type(rd, imm):
    """Encode J-type instruction (JAL)."""
    imm = imm & 0x1FFFFF  # 21-bit immediate (bit 0 always 0)
    imm_20 = (imm >> 20) & 0x1
    imm_19_12 = (imm >> 12) & 0xFF
    imm_11 = (imm >> 11) & 0x1
    imm_10_1 = (imm >> 1) & 0x3FF
    return (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | \
           (imm_19_12 << 12) | (rd << 7) | OPCODE_JAL

# =============================================================================
# Parser Helpers
# =============================================================================

def parse_immediate(imm_str, labels=None, current_addr=None, is_branch=False, is_jump=False):
    """Parse immediate value (decimal, hex, or label)."""
    imm_str = imm_str.strip()
    
    # Check for label
    if labels is not None and imm_str in labels:
        target_addr = labels[imm_str]
        if is_branch or is_jump:
            # PC-relative offset
            return target_addr - current_addr
        else:
            return target_addr
    
    # Try to parse as number
    try:
        if imm_str.startswith('0x') or imm_str.startswith('0X'):
            return int(imm_str, 16)
        elif imm_str.startswith('-0x') or imm_str.startswith('-0X'):
            return -int(imm_str[1:], 16)
        else:
            return int(imm_str)
    except ValueError:
        raise ValueError(f"Invalid immediate value: {imm_str}")

def parse_mem_operand(operand):
    """Parse memory operand like '0(x1)' or 'offset(rs1)'."""
    match = re.match(r'(-?\w+)\s*\(\s*(\w+)\s*\)', operand.strip())
    if match:
        offset_str = match.group(1)
        reg_str = match.group(2)
        return offset_str, reg_str
    raise ValueError(f"Invalid memory operand: {operand}")

# =============================================================================
# Assembler Class
# =============================================================================

class RV32IAssembler:
    """Two-pass RISC-V RV32I assembler."""
    
    def __init__(self):
        self.labels = {}
        self.instructions = []
        self.errors = []
    
    def parse_line(self, line, line_num):
        """Parse a single line, handling labels and comments.
        
        Returns:
            (label, instruction, comment) tuple
        """
        original_line = line
        comment = None
        
        # Extract comment
        if '#' in line:
            idx = line.index('#')
            comment = line[idx+1:].strip()
            line = line[:idx]
        elif '//' in line:
            idx = line.index('//')
            comment = line[idx+2:].strip()
            line = line[:idx]
        
        line = line.strip()
        if not line:
            return None, None, None
        
        # Check for label
        label = None
        if ':' in line:
            parts = line.split(':', 1)
            label = parts[0].strip()
            line = parts[1].strip() if len(parts) > 1 else ''
        
        return label, line if line else None, comment
    
    def first_pass(self, lines):
        """First pass: collect labels and their addresses."""
        address = 0
        
        for line_num, line in enumerate(lines, 1):
            try:
                label, instruction, comment = self.parse_line(line, line_num)
                
                if label:
                    if label in self.labels:
                        self.errors.append(f"Line {line_num}: Duplicate label '{label}'")
                    else:
                        self.labels[label] = address
                
                if instruction:
                    address += 4  # Each instruction is 4 bytes
                    
            except Exception as e:
                self.errors.append(f"Line {line_num}: {e}")
    
    def encode_instruction(self, instr_str, address, line_num):
        """Encode a single instruction string to machine code."""
        # Tokenize
        instr_str = instr_str.replace(',', ' ').replace('  ', ' ')
        tokens = instr_str.split()
        
        if not tokens:
            return None
        
        mnemonic = tokens[0].lower()
        operands = tokens[1:]
        
        try:
            # NOP pseudo-instruction
            if mnemonic == 'nop':
                return encode_i_type(0, 0, 0, 0, OPCODE_I_ALU)
            
            # R-type instructions
            if mnemonic in R_TYPE:
                if len(operands) != 3:
                    raise ValueError(f"Expected 3 operands for {mnemonic}")
                rd = parse_register(operands[0])
                rs1 = parse_register(operands[1])
                rs2 = parse_register(operands[2])
                funct7, funct3 = R_TYPE[mnemonic]
                return encode_r_type(rd, rs1, rs2, funct3, funct7)
            
            # I-type ALU instructions
            if mnemonic in I_TYPE_ALU:
                if len(operands) != 3:
                    raise ValueError(f"Expected 3 operands for {mnemonic}")
                rd = parse_register(operands[0])
                rs1 = parse_register(operands[1])
                imm = parse_immediate(operands[2], self.labels)
                funct3 = I_TYPE_ALU[mnemonic]
                return encode_i_type(rd, rs1, imm, funct3, OPCODE_I_ALU)
            
            # I-type shift instructions
            if mnemonic in I_TYPE_SHIFT:
                if len(operands) != 3:
                    raise ValueError(f"Expected 3 operands for {mnemonic}")
                rd = parse_register(operands[0])
                rs1 = parse_register(operands[1])
                shamt = parse_immediate(operands[2], self.labels)
                funct7, funct3 = I_TYPE_SHIFT[mnemonic]
                return encode_i_type_shift(rd, rs1, shamt, funct3, funct7)
            
            # Load instructions
            if mnemonic in LOAD_TYPE:
                if len(operands) != 2:
                    raise ValueError(f"Expected 2 operands for {mnemonic}")
                rd = parse_register(operands[0])
                offset_str, rs1_str = parse_mem_operand(operands[1])
                rs1 = parse_register(rs1_str)
                offset = parse_immediate(offset_str, self.labels)
                funct3 = LOAD_TYPE[mnemonic]
                return encode_i_type(rd, rs1, offset, funct3, OPCODE_LOAD)
            
            # Store instructions
            if mnemonic in STORE_TYPE:
                if len(operands) != 2:
                    raise ValueError(f"Expected 2 operands for {mnemonic}")
                rs2 = parse_register(operands[0])
                offset_str, rs1_str = parse_mem_operand(operands[1])
                rs1 = parse_register(rs1_str)
                offset = parse_immediate(offset_str, self.labels)
                funct3 = STORE_TYPE[mnemonic]
                return encode_s_type(rs1, rs2, offset, funct3)
            
            # Branch instructions
            if mnemonic in BRANCH_TYPE:
                if len(operands) != 3:
                    raise ValueError(f"Expected 3 operands for {mnemonic}")
                rs1 = parse_register(operands[0])
                rs2 = parse_register(operands[1])
                offset = parse_immediate(operands[2], self.labels, address, is_branch=True)
                funct3 = BRANCH_TYPE[mnemonic]
                return encode_b_type(rs1, rs2, offset, funct3)
            
            # JAL instruction
            if mnemonic == 'jal':
                if len(operands) == 1:
                    # jal label -> jal ra, label
                    rd = 1  # ra
                    offset = parse_immediate(operands[0], self.labels, address, is_jump=True)
                elif len(operands) == 2:
                    rd = parse_register(operands[0])
                    offset = parse_immediate(operands[1], self.labels, address, is_jump=True)
                else:
                    raise ValueError(f"Expected 1 or 2 operands for jal")
                return encode_j_type(rd, offset)
            
            # JALR instruction
            if mnemonic == 'jalr':
                if len(operands) == 2:
                    # jalr rd, rs1 (offset=0)
                    rd = parse_register(operands[0])
                    rs1 = parse_register(operands[1])
                    offset = 0
                elif len(operands) == 3:
                    # jalr rd, rs1, offset
                    rd = parse_register(operands[0])
                    rs1 = parse_register(operands[1])
                    offset = parse_immediate(operands[2], self.labels)
                else:
                    raise ValueError(f"Expected 2 or 3 operands for jalr")
                return encode_i_type(rd, rs1, offset, 0b000, OPCODE_JALR)
            
            # LUI instruction
            if mnemonic == 'lui':
                if len(operands) != 2:
                    raise ValueError(f"Expected 2 operands for lui")
                rd = parse_register(operands[0])
                imm = parse_immediate(operands[1], self.labels)
                return encode_u_type(rd, imm, OPCODE_LUI)
            
            # AUIPC instruction
            if mnemonic == 'auipc':
                if len(operands) != 2:
                    raise ValueError(f"Expected 2 operands for auipc")
                rd = parse_register(operands[0])
                imm = parse_immediate(operands[1], self.labels)
                return encode_u_type(rd, imm, OPCODE_AUIPC)
            
            raise ValueError(f"Unknown instruction: {mnemonic}")
            
        except Exception as e:
            raise ValueError(f"{e}")
    
    def second_pass(self, lines):
        """Second pass: encode instructions."""
        address = 0
        
        for line_num, line in enumerate(lines, 1):
            try:
                label, instruction, comment = self.parse_line(line, line_num)
                
                if instruction:
                    encoded = self.encode_instruction(instruction, address, line_num)
                    if encoded is not None:
                        # Store address, encoded instruction, original text, and comment
                        self.instructions.append((address, encoded, instruction, comment))
                        address += 4
                        
            except Exception as e:
                self.errors.append(f"Line {line_num}: {e}")
    
    def assemble(self, source):
        """Assemble source code string."""
        lines = source.split('\n')
        
        # First pass: collect labels
        self.first_pass(lines)
        
        if self.errors:
            return False
        
        # Second pass: encode instructions
        self.second_pass(lines)
        
        return len(self.errors) == 0
    
    def get_output(self):
        """Get formatted output string."""
        lines = []
        for address, encoded, original, comment in self.instructions:
            # Format: ADDRESS: HEX  # original instruction  # comment
            if comment:
                lines.append(f"{address:08X}: {encoded:08X}  # {original}  # {comment}")
            else:
                lines.append(f"{address:08X}: {encoded:08X}  # {original}")
        return '\n'.join(lines)

# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='RISC-V RV32I Assembler',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python assembler.py test.asm
    python assembler.py test.asm -o output.txt
    
Output format:
    <address>: <instruction_hex>
    00000000: 00A00093
    00000004: 01400113
        """
    )
    parser.add_argument('input', help='Input assembly file (.asm)')
    parser.add_argument('-o', '--output', help='Output file (default: output_tools/<input>.txt)')
    
    args = parser.parse_args()
    
    # Determine output filename
    if args.output:
        output_file = args.output
    else:
        # Get base name without path and extension
        import os
        base_name = os.path.basename(args.input)
        if base_name.endswith('.asm'):
            base_name = base_name[:-4]
        
        # Output to output_tools/ directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(script_dir)
        output_dir = os.path.join(project_root, 'output_tools')
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, base_name + '.txt')
    
    # Read input file
    try:
        with open(args.input, 'r') as f:
            source = f.read()
    except FileNotFoundError:
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading input file: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Assemble
    assembler = RV32IAssembler()
    success = assembler.assemble(source)
    
    if not success:
        print("Assembly errors:", file=sys.stderr)
        for error in assembler.errors:
            print(f"  {error}", file=sys.stderr)
        sys.exit(1)
    
    # Write output
    try:
        with open(output_file, 'w') as f:
            f.write(assembler.get_output())
            f.write('\n')
        print(f"Assembled {len(assembler.instructions)} instructions -> {output_file}")
    except Exception as e:
        print(f"Error writing output file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
