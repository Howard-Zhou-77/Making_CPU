`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    
    output wire stallreq,

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata, 

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`BR_WD-1:0] br_bus,
    
    input wire ex_wreg,
    input wire [4:0] ex_waddr,
    input wire [31:0] ex_wdata,
    input wire ex_opl,

    
    input wire mem_wreg,
    input wire [4:0] mem_waddr,
    input wire [31:0] mem_wdata ,

    input wire wb_wreg,
    input wire [4:0] wb_waddr,
    input wire [31:0] wb_wdata

);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    wire [31:0] inst;
    wire [31:0] id_pc;
    wire ce;

    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end
    
    assign inst = inst_sram_rdata;
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;

    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;

    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  ),
        .ex_wreg    (ex_wreg  ),
        .ex_waddr   (ex_waddr ),
        .ex_wdata   (ex_wdata ),
        
        .mem_wreg    (mem_wreg  ),
        .mem_waddr   (mem_waddr ),
        .mem_wdata   (mem_wdata ),

        .wb_wreg    (wb_wreg  ),
        .wb_waddr   (wb_waddr ),
        .wb_wdata   (wb_wdata )
    );

    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

    wire inst_ori, inst_lui, inst_addiu, inst_beq, inst_bne, inst_sll, inst_sw, inst_lw, inst_slt, 
         inst_slti, inst_sltiu, inst_sltu, inst_xor, inst_j, inst_sra, inst_srav, inst_srl, inst_srlv,
         insr_nor;

    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

    
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];
    assign inst_bne     = op_d[6'b00_0101];
    assign inst_subu    = op_d[6'b00_0000] & func_d[6'b10_0011];
    assign inst_jal     = op_d[6'b00_0011];
    assign inst_jr      = op_d[6'b00_0000] & func_d[6'b00_1000];
    assign inst_lw      = op_d[6'b10_0011];
    assign inst_addu    = op_d[6'b00_0000] & func_d[6'b10_0001];
    assign inst_or      = op_d[6'b00_0000] & func_d[6'b10_0101];
    assign inst_sll     = op_d[6'b00_0000] & func_d[6'b00_0000];
    assign inst_sw      = op_d[6'b10_1011];
    assign inst_slt     = op_d[6'b00_0000] & func_d[6'b10_1010];
    assign inst_slti    = op_d[6'b00_1010];
    assign inst_sltiu   = op_d[6'b00_1011];
    assign inst_sltu    = op_d[6'b00_0000] & func_d[6'b10_1011];
    assign inst_xor     = op_d[6'b00_0000] & func_d[6'b10_0110];
    assign inst_j       = op_d[6'b00_0010];
    assign inst_add     = op_d[6'b00_0000] & func_d[6'b10_0000];
    assign inst_sub     = op_d[6'b00_0000] & func_d[6'b10_0010];
    assign inst_and     = op_d[6'b00_0000] & func_d[6'b10_0100];
    assign inst_andi    = op_d[6'b00_1100];
    assign inst_xori    = op_d[6'b00_1110];
    assign inst_sllv    = op_d[6'b00_0000] & func_d[6'b00_0100];
    assign inst_addi    = op_d[6'b00_1000];
    assign inst_sra     = op_d[6'b00_0000]&func_d[6'b00_0011];
    assign inst_srav    = op_d[6'b00_0000]&func_d[6'b00_0111];
    assign inst_srl     = op_d[6'b00_0000]&func_d[6'b00_0010];
    assign inst_srlv    = op_d[6'b00_0000]&func_d[6'b00_0110];
    assign inst_nor     = op_d[6'b00_0000]&func_d[6'b10_0111];

    // rs to reg1
    assign sel_alu_src1[0] = inst_ori | inst_addiu | inst_subu | inst_jr | inst_lw | inst_addu | 
                             inst_or | inst_sw | inst_bne | inst_slt | inst_slti | inst_sltiu | 
                             inst_sltu | inst_xor | inst_add | inst_sub | inst_and | inst_andi | 
                             inst_xori | inst_sllv | inst_addi | inst_srav | inst_srlv | inst_nor;

    // pc to reg1
    assign sel_alu_src1[1] = inst_jal;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl;

    
    // rt to reg2
    assign sel_alu_src2[0] = inst_subu | inst_addu | inst_or | inst_sll | inst_bne | inst_slt | 
                             inst_sltu | inst_xor | inst_add | inst_sub | inst_and | inst_sllv |
                             inst_sra | inst_srav | inst_srl | inst_srlv | inst_nor;

    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw | inst_sw | inst_slti | inst_sltiu |
                             inst_addi;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori | inst_xori | inst_andi;



    assign op_add = inst_addiu | inst_jal | inst_lw | inst_addu | inst_sw | inst_add | inst_addi;
    assign op_sub = inst_subu | inst_sub;
    assign op_slt = inst_slt | inst_slti;
    assign op_sltu = inst_sltiu | inst_sltu;
    assign op_and = inst_and | inst_andi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xor | inst_xori;
    assign op_sll = inst_sll | inst_sllv;
    assign op_srl = inst_srl | inst_srlv;
    assign op_sra = inst_sra | inst_srav;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable
    assign data_ram_en = inst_lw | inst_sw;

    // write enable
    assign data_ram_wen = inst_sw ? 4'b1111 : 
                          inst_lw ? 4'b0000 : 4'b0;



    // regfile sotre enable

    assign rf_we = inst_ori | inst_lui | inst_addiu | inst_jal | inst_subu | inst_addu 
                 | inst_or | inst_lw | inst_sll | inst_slt | inst_slti | inst_sltiu | inst_sltu
                 | inst_xor | inst_add | inst_sub | inst_and | inst_andi | inst_xori | inst_sllv 
                 | inst_addi | inst_sra | inst_srav | inst_srl | inst_srlv | inst_nor;





    // store in [rd]
    assign sel_rf_dst[0] = inst_subu | inst_addu | inst_or | inst_sll | inst_slt | inst_sltu | 
                           inst_xor | inst_add | inst_sub | inst_and | inst_sllv | inst_sra | 
                           inst_srav | inst_srl | inst_srlv | inst_nor;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu | inst_lw | inst_slti | inst_sltiu | 
                           inst_andi | inst_xori | inst_addi;
    // store in [31]
    assign sel_rf_dst[2] = inst_jal;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from load_res
    assign sel_rf_res = inst_lw ; 

    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rdata1,         // 63:32
        rdata2          // 31:0
    };


    wire br_e;                                  // 是否满足跳转
    wire [31:0] br_addr;                        // 
    wire rs_eq_rt;                              //
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;

    assign pc_plus_4 = id_pc + 32'h4;
    assign rs_eq_rt = (rdata1 == rdata2);

    assign br_e = (inst_beq & rs_eq_rt) | (inst_bne & ~rs_eq_rt) | inst_jal | inst_jr | inst_j;
    assign br_addr = (inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 
                      inst_bne ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                      inst_jal | inst_j ? ({pc_plus_4[31:28],instr_index,2'b0}) : 
                      inst_jr ? rdata1 : 32'b0);

    assign br_bus = {
        br_e,
        br_addr
    };
    
    //stall 
    assign stallreq = (ex_opl &(((ex_waddr==rs) & (sel_alu_src1[0]==1))|((ex_waddr==rt) & (sel_alu_src2[0]==1)))) ? 1 : 0;

endmodule