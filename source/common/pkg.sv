package pkg;

//-----------------------------------------------
// Instruction Fetch stage (Q100H/Q101H stage)
//-----------------------------------------------

    // Instruction fetch control signals
    typedef struct packed {
        logic               ready_Q100H;             // Ready signal for Q100H stage
        logic               ready_Q101H;             // Ready signal for Q101H stage
        logic               sel_next_pc_alu_out_Q102H; // Select ALU output for next PC (branch/jump)
    } t_if_ctrl;

//---------------------------------------------------------------
// Decode stage (Q101H stage)
//---------------------------------------------------------------

    // RV32I opcode map
    typedef enum logic [6:0] {
        LUI      = 7'b0110111,
        AUIPC    = 7'b0010111,
        JAL      = 7'b1101111,
        JALR     = 7'b1100111,
        BRANCH   = 7'b1100011,
        LOAD     = 7'b0000011,
        STORE    = 7'b0100011,
        I_OP     = 7'b0010011,
        R_OP     = 7'b0110011,
        MISC_MEM = 7'b0001111,
        SYSTEM   = 7'b1110011
    } t_opcode;

    // Immediate selection for decode/imm-gen
    typedef enum logic [2:0] {
        IMM_I_TYPE = 3'd0,
        IMM_S_TYPE = 3'd1,
        IMM_B_TYPE = 3'd2,
        IMM_U_TYPE = 3'd3,
        IMM_J_TYPE = 3'd4
    } t_imm_sel;

    // Decode stage control (for rv_decode + pipeline gating)
    typedef struct packed {
        logic       ready_Q101H;     // Enable sampling instruction into decode
        logic       ready_Q102H;     // Enable advancing decode results to EXE
        logic       valid_Q101H;     // Instruction validity after flush/inserted bubble
        logic [4:0] reg_src1_Q101H;       // Source register 1
        logic [4:0] reg_src2_Q101H;       // Source register 2
        logic [4:0] rd_Q101H;        // Destination register (raw from instr)
        logic       uses_reg_src1_Q101H;  // Hint: instruction actually needs rs1
        logic       uses_reg_src2_Q101H;  // Hint: instruction actually needs rs2
        t_imm_sel   sel_imm_type_Q101H;   // Immediate type selector
    } t_decode_ctrl;

//------------------------------
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
        logic               ready_Q102H;            // Ready signal for Q102H stage
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


//-----------------------------------------------
// Memory access (Q103H stage) 
//-----------------------------------------------
//------------------------------
    // mux for the write back data 
    typedef enum logic {
        SEL_PC_PLUS4 = 1'b0,
        SEL_ALU_OUT = 1'b1
    } t_mem_wb_sel;


    // Memory access control signals
    typedef struct packed {
        logic               ready_Q103H;         // Ready signal for Q103H stage
        t_mem_wb_sel        sel_wb_Q103H;        // mux select for the write back data 
        logic               dmem_wr_en_Q103H;    // memory write enable
        logic               dmem_rd_en_Q103H;    // memory read enable
        logic [3:0]         dmem_byte_en_Q103H;  // memory byte enable
    } t_ma_ctrl;

    // Core to memory request
    typedef struct packed {
        logic [31:0]        wr_data;           // write data
        logic [31:0]        address;           // address
        logic               wr_en;             // write enable
        logic               rd_en;             // read enable
        logic [3:0]         byte_en;           // byte enable
    } t_core2mem_req;


//-----------------------------------------------
// Write back stage (Q104H stage)
//-----------------------------------------------
    // mux for the write back data 
    typedef enum logic {
        SEL_WR_DATA = 1'b0,
        SEL_DMEM_RD_DATA = 1'b1
    } t_wb_sel;

    // Pipeline control struct (must be after all dependent types)
    typedef struct packed {
        t_alu_op            alu_op;
        t_branch_cond_op    branch_cond_op;
        t_alu_in1_sel       sel_alu_in1;
        t_alu_in2_sel       sel_alu_in2;
        t_mem_wb_sel        mem_wb_sel;
        t_wb_sel            wb_sel;
        t_imm_sel           imm_sel;
        logic [3:0]         dmem_byte_en;
        logic               dmem_wr_en;
        logic               dmem_rd_en;
        logic               reg_write_en;
        logic               is_load;
        logic               uses_rs1;
        logic               uses_rs2;
        logic [4:0]         rd;
        logic [4:0]         rs1;
        logic [4:0]         rs2;
        logic               dmem_sign_ext;
    } t_ctrl;

    // Write back control signals
    typedef struct packed {
        logic           ready_Q104H;          // Ready signal for Q104H stage
        t_wb_sel        sel_wb_Q104H;
        logic           reg_write_en_Q104H;
        logic [4:0]     reg_dst_Q104H;        // mux select for the write back data 
    } t_wb_ctrl;

endpackage
