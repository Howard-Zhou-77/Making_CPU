`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    input wire [71:0] hilo_id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    output wire [65:0] hilo_ex_to_mem_bus,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,

    output wire ex_wreg,
    output wire [4:0] ex_waddr,
    output wire [31:0] ex_wdata,
    output wire ex_opl,
    output wire ex_hi_we,
    output wire ex_lo_we,
    output wire [31:0] ex_hi_wdata,
    output wire [31:0] ex_lo_wdata,
    output wire stallreq_for_ex
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;
    reg [71:0] hilo_id_to_ex_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            hilo_id_to_ex_bus_r <= 72'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            hilo_id_to_ex_bus_r <= 72'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
            hilo_id_to_ex_bus_r <= hilo_id_to_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;

    wire [3:0] hilo_inst;
    wire [31:0] hi_rdata, lo_rdata;
    wire hi_rf_we;
    wire lo_rf_we;
    wire hi_e;
    wire lo_e;
    wire [31:0] hi_rf_wdata;
    wire [31:0] lo_rf_wdata;

    assign {
        ex_pc,          // 148:117
        inst,           // 116:85
        alu_op,         // 84:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;

    assign {
        hilo_inst,           // 71:68
        hi_rdata,            // 67:36
        lo_rdata,            // 35:4
        hi_rf_we,               // 3 
        lo_rf_we,               // 2
        hi_e,                // 1
        lo_e                 // 0
    } = hilo_id_to_ex_bus_r;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    wire inst_mfhi, inst_mflo, inst_mthi, inst_mtlo, inst_mult, inst_multu, inst_sw, inst_sb, inst_sh;

    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 : // bgtzal...
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;

    assign inst_mflo = hilo_inst == 4'b0001 ? 1 : 0;
    assign inst_mfhi = hilo_inst == 4'b0010 ? 1 : 0;
    assign inst_mtlo = hilo_inst == 4'b0011 ? 1 : 0;
    assign inst_mthi = hilo_inst == 4'b0100 ? 1 : 0;
    assign inst_mult = hilo_inst == 4'b0101 ? 1 : 0;
    assign inst_multu = hilo_inst == 4'b0110 ? 1 : 0;
    assign inst_div = hilo_inst == 4'b0111 ? 1 : 0;
    assign inst_divu = hilo_inst == 4'b1000 ? 1 : 0;
    assign inst_sw = data_ram_wen == 4'b1111 ? 1 : 0;
    assign inst_sb = data_ram_wen == 4'b0001 ? 1 : 0;
    assign inst_sh = data_ram_wen == 4'b0011 ? 1 : 0;
    
    
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    assign ex_result = inst_mfhi ? hi_rdata : 
                       inst_mflo ? lo_rdata :
                       alu_result ;

    assign ex_opl = (inst[31:26]==6'b10_0011 | inst[31:26]==6'b10_0000 | inst[31:26]==6'b10_0100 
                    |inst[31:26]==6'b10_0001 | inst[31:26]==6'b10_0101) ? 1 : 0;

    assign data_sram_en = data_ram_en;
    
    assign data_sram_wen = (inst_sb & ex_result[1:0] == 2'b00) ? 4'b0001 :
                           (inst_sb & ex_result[1:0] == 2'b01) ? 4'b0010 :
                           (inst_sb & ex_result[1:0] == 2'b10) ? 4'b0100 :
                           (inst_sb & ex_result[1:0] == 2'b11) ? 4'b1000 :
                           (inst_sh & ex_result[1:0] == 2'b00) ? 4'b0011 :
                           (inst_sh & ex_result[1:0] == 2'b10) ? 4'b1100 : 
                           inst_sw ? 4'b1111 : 4'b0; //mem wen

    assign data_sram_addr = alu_result ; //

    assign data_sram_wdata = data_sram_wen == 4'b1000 ? {rf_rdata2[7:0], rf_rdata2[7:0], rf_rdata2[7:0], rf_rdata2[7:0]} :
                             data_sram_wen == 4'b0100 ? {rf_rdata2[7:0], rf_rdata2[7:0], rf_rdata2[7:0], rf_rdata2[7:0]} : 
                             data_sram_wen == 4'b0010 ? {rf_rdata2[7:0], rf_rdata2[7:0], rf_rdata2[7:0], rf_rdata2[7:0]} :
                             data_sram_wen == 4'b0001 ? {rf_rdata2[7:0], rf_rdata2[7:0], rf_rdata2[7:0], rf_rdata2[7:0]} :
                             data_sram_wen == 4'b1100 ? {rf_rdata2[15:0], rf_rdata2[15:0]} :
                             data_sram_wen == 4'b0011 ? {rf_rdata2[15:0], rf_rdata2[15:0]} : rf_rdata2; //store data

    assign ex_to_mem_bus = {
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };


    // MUL_DIV part
    wire [63:0] mix_result;
    wire inst_mix,inst_mixu;
    wire mix_ready_i;
    reg stallreq_for_mix;

    assign stallreq_for_ex = stallreq_for_mix ;
    
    reg [31:0] mix_opdata1_o;
    reg [31:0] mix_opdata2_o;
    reg mix_start_o;
    reg signed_mix_o;
    
    assign inst_mix = inst_mult | inst_div;
    assign inst_mixu = inst_multu | inst_divu;
    mix u_mix(
    	.rst          (rst          ),
        .clk          (clk          ),
        .mul_div      (inst_div | inst_divu ),
        .signed_mix_i (signed_mix_o ),
        .opdata1_i    (mix_opdata1_o    ),
        .opdata2_i    (mix_opdata2_o    ),
        .start_i      (mix_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (mix_result     ), // ???????????? 64bit
        .ready_o      (mix_ready_i      )
    );

    always @ (*) begin
        if (rst) begin
            stallreq_for_mix = `NoStop;
            mix_opdata1_o = `ZeroWord;
            mix_opdata2_o = `ZeroWord;
            mix_start_o = `MixStop;
            signed_mix_o = 1'b0;
        end
        else begin
            stallreq_for_mix = `NoStop;
            mix_opdata1_o = `ZeroWord;
            mix_opdata2_o = `ZeroWord;
            mix_start_o = `MixStop;
            signed_mix_o = 1'b0;
            case ({inst_mix,inst_mixu})
                2'b10:begin
                    if (mix_ready_i == `MixResultNotReady) begin
                        mix_opdata1_o = rf_rdata1;
                        mix_opdata2_o = rf_rdata2;
                        mix_start_o = `MixStart;
                        signed_mix_o = 1'b1;
                        stallreq_for_mix = `Stop;
                    end
                    else if (mix_ready_i == `MixResultReady) begin
                        mix_opdata1_o = rf_rdata1;
                        mix_opdata2_o = rf_rdata2;
                        mix_start_o = `MixStop;
                        signed_mix_o = 1'b1;
                        stallreq_for_mix = `NoStop;
                    end
                    else begin
                        mix_opdata1_o = `ZeroWord;
                        mix_opdata2_o = `ZeroWord;
                        mix_start_o = `MixStop;
                        signed_mix_o = 1'b0;
                        stallreq_for_mix = `NoStop;
                    end
                end
                2'b01:begin
                    if (mix_ready_i == `MixResultNotReady) begin
                        mix_opdata1_o = rf_rdata1;
                        mix_opdata2_o = rf_rdata2;
                        mix_start_o = `MixStart;
                        signed_mix_o = 1'b0;
                        stallreq_for_mix = `Stop;
                    end
                    else if (mix_ready_i == `MixResultReady) begin
                        mix_opdata1_o = rf_rdata1;
                        mix_opdata2_o = rf_rdata2;
                        mix_start_o = `MixStop;
                        signed_mix_o = 1'b0;
                        stallreq_for_mix = `NoStop;
                    end
                    else begin
                        mix_opdata1_o = `ZeroWord;
                        mix_opdata2_o = `ZeroWord;
                        mix_start_o = `MixStop;
                        signed_mix_o = 1'b0;
                        stallreq_for_mix = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    assign hi_rf_wdata = inst_mthi ? rf_rdata1 :
                         inst_mix | inst_mixu ? mix_result[63:32] : 32'b0;
    assign lo_rf_wdata = inst_mtlo ? rf_rdata1 : 
                         inst_mix | inst_mixu ? mix_result[31:0] : 32'b0;

    assign hilo_ex_to_mem_bus ={
        hi_rf_wdata,            // 65:34
        lo_rf_wdata,            // 33:2
        hi_rf_we,               // 1 
        lo_rf_we                // 0
    };

    // mul_result ???? div_result ??????????????????
    assign ex_wreg=rf_we;
    assign ex_waddr=rf_waddr;
    assign ex_wdata=ex_result;
    assign ex_hi_we=hi_rf_we;
    assign ex_lo_we=lo_rf_we;
    assign ex_hi_wdata=hi_rf_wdata;
    assign ex_lo_wdata=lo_rf_wdata;
    
endmodule