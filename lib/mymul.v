`include "defines.vh"

module mymul(
	input wire rst,							//复位
	input wire clk,							//时钟
	input wire signed_mul_i,				//是否为有符号乘法运算，1位有符号
	input wire[31:0] opdata1_i,				//操作数1
	input wire[31:0] opdata2_i,				//操作数2
	input wire start_i,						//是否开始乘法运算
	input wire annul_i,						//是否取消乘法运算，1位取消
	output reg[63:0] result_o,				//乘法运算结果
	output reg ready_o						//乘法运算是否结束
	
);

	reg [5:0] cnt;							//迭代次数
	reg[63:0] mul_res;					
	reg [1:0] state;						//乘法器处于的状态	
	reg[31:0] temp_op1;                     //操作数1
	reg[31:0] temp_op2;                     //操作数2
    reg[63:0] temp_num;                     //中间操作数
	
	
	always @ (posedge clk) begin
		if (rst) begin
			state <= `MulFree;
			result_o <= {`ZeroWord,`ZeroWord};
			ready_o <= `MulResultNotReady;
		end else begin
			case(state)
			
				`MulFree: begin			//乘法法器空闲
					if (start_i == `MulStart && annul_i == 1'b0) begin
						state <= `MulOn;					
						cnt <= 6'b000000;
						if(signed_mul_i == 1'b1 && opdata1_i[31] == 1'b1) begin			//操作数1为负数
								temp_op1 = ~opdata1_i + 1;
						end else begin
								temp_op1 = opdata1_i;
						end
						if (signed_mul_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin			//操作数2为负数
								temp_op2 = ~opdata2_i + 1;
						end else begin
								temp_op2 = opdata2_i;
						end
						mul_res <= {`ZeroWord, `ZeroWord};
                        temp_num <= {`ZeroWord, temp_op1};
					end else begin
						ready_o <= `MulResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
				`MulOn: begin				
					if(annul_i == 1'b0) begin			//进行乘法运算
						if(cnt != 6'b100000) begin
							mul_res <= mul_res + (temp_op2[cnt] == 1'b1 ? temp_num : 0);
                            temp_num <= (temp_num << 1);
							cnt <= cnt +1;		//乘法运算次数
						end	else begin
							if ((signed_mul_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
								mul_res = ~mul_res + 1;
							end
							state <= `MulEnd;
							cnt <= 6'b000000;
						end
					end else begin	
						state <= `MulFree;
					end
				end
				
				`MulEnd: begin			//乘法结束
					result_o <= mul_res;
					ready_o <= `MulResultReady;
					if (start_i == `MulStop) begin
						state <= `MulFree;
						ready_o <= `MulResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
			endcase
		end
	end


endmodule