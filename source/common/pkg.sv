package pkg;

// Execute stage (Q102H stage)
//------------------------------

    // ALU operation types
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b1000,
        ALU_SLT  = 4'b0010,
        ALU_SLTU = 4'b0011,
        ALU_SLL  = 4'b0001,
        ALU_SRL  = 4'b0101,
        ALU_SRA  = 4'b1101,
        ALU_XOR  = 4'b0100,
        ALU_OR   = 4'b0110,
        ALU_AND  = 4'b0111
    } t_alu_op;

    // Branch condition operation type
    typedef enum logic [2:0] {
        BRANCH_COND_NONE = 3'b000,
        BRANCH_COND_BEQ  = 3'b001,
        BRANCH_COND_BNE  = 3'b010,
        BRANCH_COND_BLT  = 3'b011,
        BRANCH_COND_BGE  = 3'b100,
        BRANCH_COND_BLTU = 3'b101,
        BRANCH_COND_BGEU = 3'b110
    } t_branch_cond_op;

    // ALU in the exe input select type
    typedef enum logic {
        SEL_PC = 1'b0,
        SEL_REG_DATA1 = 1'b1
    } t_alu_in1_sel;

    typedef enum logic {
        SEL_REG_DATA2 = 1'b0,
        SEL_IMM = 1'b1
    } t_alu_in2_sel;


    // Execute stage control signals
    typedef struct packed {
        logic [4:0]         rs1_Q102H;              // Source register 1 address
        logic [4:0]         rs2_Q102H;              // Source register 2 address
        logic [4:0]         rd_Q103H;               // Destination register address from Q103H (for forwarding)
        logic [4:0]         rd_Q104H;               // Destination register address from Q104H (for forwarding)
        logic               reg_write_en_Q103H;        // Register write enable from Q103H (for forwarding)
        logic               reg_write_en_Q104H;        // Register write enable from Q104H (for forwarding)
        t_alu_in1_sel       sel_alu_in1_Q102H;      // ALU input 1 select (SEL_REG_DATA or SEL_PC)
        t_alu_in2_sel       sel_alu_in2_Q102H;      // ALU input 2 select (SEL_REG_DATA or SEL_IMM)
        t_alu_op            alu_op;                 // ALU operation
        t_branch_cond_op    branch_cond_op;         // Branch condition operation
    } t_exe_ctrl;


//  Memory access (Q103H stage) 
//------------------------------
    // mux for the write back data 
    typedef enum logic {
        SEL_PC_PLUS4 = 1'b0,
        SEL_ALU_OUT = 1'b1
    } t_mem_wb_sel;


    // Memory access control signals
    typedef struct packed {
        t_mem_wb_sel        sel_wb_Q103H;        // mux select for the write back data 
        logic               dmem_wr_en_Q103H;    // memory write enable
        logic               dmem_rd_en_Q103H;    // memory read enable
        logic [3:0]         dmem_byte_en_Q103H;  // memory byte enable
    } t_mem_ctrl;

    // Core to memory request
    typedef struct packed {
        logic [31:0]        wr_data;           // write data
        logic [31:0]        address;           // address
        logic               wr_en;             // write enable
        logic               rd_en;             // read enable
        logic [3:0]         byte_en;           // byte enable
    } t_core2mem_req;


// Write back stage (Q104H stage)
//------------------------------

    // mux for the write back data 
    typedef enum logic {
        SEL_WR_DATA = 1'b0,
        SEL_DMEM_RD_DATA = 1'b1
    } t_wb_sel;

    // Write back control signals
    typedef struct packed {
        t_wb_sel        sel_wb_Q104H;
        logic           reg_write_en_Q104H;
        logic [4:0]     reg_dst_Q104H;        // mux select for the write back data 
    } t_wb_ctrl;

endpackage
