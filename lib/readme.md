自制乘法器说明文档:
模块输入输出:
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

仿照32位除法器实现的移位乘法器。
模拟乘法操作，将32位操作数1乘32位操作数2转化为，操作数1每次左移1位，并在操作数2对应位数为1时累加。乘法结果为64位，每次移位需要一个周期，共需要32各周期。
temp_num：操作数1每次左移后的值
if(cnt != 6'b100000) begin
	mul_res <= mul_res + (temp_op2[cnt] == 1'b1 ? temp_num : 0); //如果操作数2该位为1最后结果累加上temp_num
    temp_num <= (temp_num << 1); //每次迭代左移以为
	cnt <= cnt +1;		//乘法运算次数
end	else begin
	if ((signed_mul_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) 
    begin
	mul_res = ~mul_res + 1;
	end
	state <= `MulEnd;
	cnt <= 6'b000000;
end


调用方法：采用always时序逻辑传入模块需要的输入，根据输出ready_o判断乘法运算是否结束，result_o为最后的输出。