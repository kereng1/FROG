// D Flip-Flop Macros (dff_macros.svh)
// Contains common synchronous logic definitions for DFFs and memory elements.

`ifndef DFF_MACROS_SVH
`define DFF_MACROS_SVH

// -----------------------------------------------------------------------------
// Core DFF Definitions
// -----------------------------------------------------------------------------

// Basic D-Flip Flop (Q <= D on posedge CLK)
`define DFF(Q, D, CLK) \
    always_ff @(posedge CLK) begin \
        Q <= D; \
    end

// D-Flip Flop with Asynchronous Reset (Q <= 0 on RST, else Q <= D)
`define DFF_RST(Q, D, CLK, RST) \
    always_ff @(posedge CLK) begin \
        if (RST) Q <= '0; \
        else     Q <= D; \
    end

// D-Flip Flop with Asynchronous Reset to a specific value
`define DFF_RST_VAL(Q, D, CLK, RST, RESET_VAL) \
    always_ff @(posedge CLK) begin \
        if (RST) Q <= RESET_VAL; \
        else     Q <= D; \
    end

// D-Flip Flop with Clock Enable (Q <= IN only if EN is active)
`define DFF_EN(Q, D, CLK, EN) \
    always_ff @(posedge CLK) begin \
        if (EN) Q <= D; \
    end

// DFF with both Reset and Enable
`define DFF_RST_EN(OUT, IN, CLK, EN, RST, RST_VAL) \
    always_ff @(posedge CLK) begin \
        if (RST) OUT <= RST_VAL; \
        else if (EN) OUT <= IN; \
    end

// -----------------------------------------------------------------------------
// Memory Macros
// -----------------------------------------------------------------------------

// Macro for memory array DFF with Write Enable (used for synchronous RAM write access)
// It iterates through the entire array size ($size(MEM)) and transfers NEXT_MEM to MEM.
// This supports both Byte-Array (1024 depth) and Word-Array (256 depth).
`define DFF_MEM(MEM, NEXT_MEM, CLK, EN) \
    always_ff @(posedge CLK) begin \
        if (EN) begin \
            for (int i = 0; i < $size(MEM); i++) begin \
                MEM[i] <= NEXT_MEM[i]; \
            end \
        end \
    end


`endif // DFF_MACROS_SVH