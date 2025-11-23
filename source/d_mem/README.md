Core Design: Word-Aligned Access with Shift Logic

This module serves as the critical interface between the CPU pipeline and the physical, 32-bit Block RAM. Its primary function is to correctly handle all Load and Store operations, especially those that access memory at unaligned addresses (Byte, Halfword).

1. The Principle of Alignment Translation

The design intelligently uses the two least significant bits of the incoming address (adrs[1:0]), known as the Offset, to manage all access requests.

Store (Write) Mechanism: On a write operation, the incoming data (wr_data) undergoes a Shift Left operation. This mechanism dynamically pushes the data into the exact Byte Lane (Offset 0, 1, 2, or 3) where it needs to reside within the 32-bit memory word. This ensures that the physical memory is updated correctly, even when only a single byte is being stored.

Load (Read) Mechanism: On a read operation, the memory always returns the full 32-bit word. The required data (Byte or Halfword) is extracted by an opposing Shift Right operation. This shift moves the requested data from its floating position within the 32-bit word down to the Least Significant Bits (LSB). The data is now properly aligned and ready for the next pipeline stage to apply Sign or Zero Extension.

2. Advantages and Flexibility

The module is explicitly built for high-performance and future-proofing:

Parameterization: The architecture is generic, utilizing parameters like WORD_WIDTH and ADRS_WIDTH. This design choice allows for immediate and easy scaling to wider architectures (such as 64-bit systems) simply by modifying the initial parameter values.

Control Efficiency: The module employs separate rden (Read Enable) and wren (Write Enable) control signals. This single-port control strategy is the standard, most efficient method for interfacing with synchronous Block RAMs in any pipelined CPU environment, ensuring clear separation of Load and Store functions within the MEM stage.

Partial Access Support: Full support for Byte and Halfword operations is implemented by dynamically adjusting the data position using the Offset. This eliminates the need for slow read-modify-write cycles for small data stores.

3. Interface Overview

The module communicates using standard signals: adrs provides the full address, rden and wren control the access type, and rd_data outputs the fully aligned result, where the requested byte or halfword is always positioned at the LSB.

4. Running Commands

vlog +incdir+source/common source/d_mem/d_mem_Word_Aligned_Block_RAM.sv verif/d_mem_tb.sv
vsim work.mem_tb