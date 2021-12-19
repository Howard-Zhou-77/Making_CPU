`include "defines.vh"

module mix(
	input wire rst,							//复位
	input wire clk,							//时钟
	input wire mul_div,                    //乘或除
	input wire signed_mix_i,			    //是否为有符号乘除法运算，1位有符号
	input wire[31:0] opdata1_i,				//操作数1
	input wire[31:0] opdata2_i,				//操作数2
	input wire start_i,						//是否开始乘除法运算
	input wire annul_i,						//是否取消乘除法运算，1位取消
	output reg[63:0] result_o,				//乘除法运算结果
	output reg ready_o						//乘除法运算是否结束
	
);
	
	reg [5:0] cnt;							//迭代次数
	reg [1:0] state;						//乘除法器处于的状态	
	reg[31:0] temp_op1;                     //操作数1
	reg[31:0] temp_op2;                     //操作数2
	reg[63:0] temp_num;                     //中间操作数
	reg[63:0] mix_res;                      //乘除法运算结果	
		
	always @ (posedge clk) begin
		if (rst) begin
			state <= `MixFree;
			result_o <= {`ZeroWord,`ZeroWord};
			ready_o <= `MixResultNotReady;
		end else begin
			case(state)
			
				`MixFree: begin			//乘除法器空闲
					if (start_i == `MixStart && annul_i == 1'b0) begin
						if(opdata2_i == `ZeroWord && mul_div == 1'b1) begin			//如果乘除数为0
							state <= `MixByZero;
						end else begin
							state <= `MixOn;					//乘除数不为0
							cnt <= 6'b000000;
							if(signed_mix_i == 1'b1 && opdata1_i[31] == 1'b1) begin			//被乘除数为负数
								temp_op1 = ~opdata1_i + 1;
							end else begin
								temp_op1 = opdata1_i;
							end
							if (signed_mix_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin			//乘除数为负数
								temp_op2 = ~opdata2_i + 1;
							end else begin
								temp_op2 = opdata2_i;
							end
							mix_res <= {`ZeroWord, `ZeroWord};
							temp_num <= {`ZeroWord, temp_op1};
						end
					end else begin
						ready_o <= `MixResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
				`MixByZero: begin			//除数为0
					mix_res <= {`ZeroWord, `ZeroWord};
					state <= `MixEnd;
				end
				
				`MixOn: begin				//乘除数不为0
					if(annul_i == 1'b0) begin			//进行乘除法运算
						if(cnt != 6'b100000) begin
							if(mul_div == 1'b0) begin
							    mix_res <= mix_res + (temp_op2[cnt] == 1'b1 ? temp_num : 0);
                                temp_num <= (temp_num << 1);
							end else begin
								temp_num[31:0] = {mix_res[62:32],temp_op1[31-cnt]};
							    if(temp_num[31:0] >= temp_op2) begin
								    mix_res[63:32] <= temp_num[31:0]- temp_op2;
							        mix_res[31-cnt] <= 1;
							    end else begin
								    mix_res[63:32] <= temp_num[31:0];
								    mix_res[31-cnt] <= 0;
							    end
							end
							cnt <= cnt +1;		//乘除法运算次数
						end	else begin
							if ((signed_mix_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
								if(mul_div == 1'b0) begin
									mix_res <= ~mix_res + 1;
								end else begin
									mix_res[31:0] <= (~mix_res[31:0] + 1);
								end
							end
							if ((signed_mix_i == 1'b1) && ((opdata1_i[31] ^ mix_res[63]) == 1'b1)) begin
								if(mul_div == 1'b1) begin
									mix_res[63:32] <= (~mix_res[63:32] + 1);
								end
							end
							state <= `MixEnd;
							cnt <= 6'b000000;
						end
					end else begin	
						state <= `MixFree;
					end
				end
				
				`MixEnd: begin			//乘除法结束
					result_o <= mix_res;
					ready_o <= `MixResultReady;
					if (start_i == `MixStop) begin
						state <= `MixFree;
						ready_o <= `MixResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
			endcase
		end
	end


endmodule