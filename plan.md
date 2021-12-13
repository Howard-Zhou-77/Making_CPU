## 目前的计划：

1. [ ] Операция Заря - 完成对局部通路和stall的设计，解锁Point 1
2. [ ] Операция Труд - 完成所有的branch和jump语句。
3. [ ] Операция Память - 写入所有的四则运算指令。

### 1. Операция Заря 黎明行动

首先是局部通路。

注意初始文档到EX.v 77 -82L:

```verilog
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );
```

显然，要实现在ALU执行前进行通路，只需在执行前先进行一个信号截留，即用上一个的结果代换`alu_src1`和`alu_scr2`两个变量。

接下来分析：

```verilog
    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :                         //32'd8 = 0000 0000 0000 1000
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
```

这里使用了好几个三目运算符(`A?B:C`)的嵌套。可以看到运算符最主要的加工一是通过`sel_alu_srcX`判定是否是寄存器，二是如果是16位立即数则对其进行符号位拓展。

那么我们所做的就是增加和删减`input`和`output`。当然这是个大工作，涉及几个`.v`文件的调整。

首先我们发现，这里调取寄存器时用到的两个变量`rf_rdataX`的定义要追溯到`ID.v`：
```verilog
    wire [31:0] rdata1, rdata2;

    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );
```

那么查找`lib/regfile.v`可以找到这个函数的原型：
```verilog
`include "defines.vh"
module regfile(
    input wire clk,
    input wire [4:0] raddr1,
    output wire [31:0] rdata1,
    input wire [4:0] raddr2,
    output wire [31:0] rdata2,
    
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata
);
    reg [31:0] reg_array [31:0];
    // write
    always @ (posedge clk) begin
        if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
        end
    end

    // read out 1
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : reg_array[raddr1];

    // read out2
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : reg_array[raddr2];
endmodule
```

那么我们要做的第一步就是在`ID.v`上加入几根(\**我这里没有用错量词，因为类型是wire 导线，导线可不就是一根根的吗*)变量后，检查从EX和MEM段传来的参数，然后修改`lib/regfile.v`使`rdataX`在调取内容前遭到截流：

```verilog
    // read out 1
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : 
                    (ex_wreg == 1'b1 && ex_waddr==raddr1) ? ex_wdata :
                    (mem_wreg == 1'b1 && mem_waddr==raddr1) ? mem_wdata : reg_array[raddr1];

    // read out2
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 :
                    (ex_wreg == 1'b1 && ex_waddr==raddr2) ? ex_wdata :
                    (mem_wreg == 1'b1 && mem_waddr==raddr2) ? mem_wdata : reg_array[raddr2];
```

然后就是修改`EX.v`和`MEM.v`，在其中写入向下一段ID段传递的参数，再重写`mycpu_core.v`的相关模块：

```verilog
    ID u_ID(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .stallreq        (stallreq        ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_rdata (inst_sram_rdata ),
        .wb_to_rf_bus    (wb_to_rf_bus    ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .br_bus          (br_bus          ),
        .ex_wreg         (ex_to_id_reg    ),
        .ex_waddr        (ex_to_id_add    ),
        .ex_wdata        (ex_to_id_data   ),
        .mem_wreg        (mem_to_id_reg   ),
        .mem_waddr       (mem_to_id_add   ),
        .mem_wdata       (mem_to_id_data  ),
    );

    EX u_EX(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .data_sram_en    (data_sram_en    ),
        .data_sram_wen   (data_sram_wen   ),
        .data_sram_addr  (data_sram_addr  ),
        .data_sram_wdata (data_sram_wdata ),
        .ex_wreg         (ex_to_id_reg    ),
        .ex_waddr        (ex_to_id_add    ),
        .ex_wdata        (ex_to_id_data   )
    );

    MEM u_MEM(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .data_sram_rdata (data_sram_rdata ),
        .mem_to_wb_bus   (mem_to_wb_bus   ),
        .mem_wreg        (mem_to_id_reg   ),
        .mem_waddr       (mem_to_id_add   ),
        .mem_wdata       (mem_to_id_data  )
    );
```

然后下一步就是设计stall相关。

-- 待续 --

### 2. Операция Труд 劳动行动 3. Операция Память 记忆行动

在写出了局部通路之后我们再运行发现提示变成了这个：

```
--------------------------------------------------------------
[   2327 ns] Error!!!
    reference: PC = 0xbfc006f8, wb_rf_wnum = 0x19, wb_rf_wdata = 0x9fc00704
    mycpu    : PC = 0xbfc00714, wb_rf_wnum = 0x19, wb_rf_wdata = 0xbfc00000
--------------------------------------------------------------
```

比照`test.s`：

```s
bfc006b8 <locate>:
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:271
bfc006b8:	3c04bfaf 	lui	a0,0xbfaf
bfc006bc:	3484f008 	ori	a0,a0,0xf008
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:272
bfc006c0:	3c05bfaf 	lui	a1,0xbfaf
bfc006c4:	34a5f004 	ori	a1,a1,0xf004
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:273
bfc006c8:	3c11bfaf 	lui	s1,0xbfaf
bfc006cc:	3631f010 	ori	s1,s1,0xf010
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:275
bfc006d0:	24090002 	li	t1,2
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:276
bfc006d4:	240a0001 	li	t2,1
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:277
bfc006d8:	3c130000 	lui	s3,0x0
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:279
bfc006dc:	ac890000 	sw	t1,0(a0)
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:280
bfc006e0:	acaa0000 	sw	t2,0(a1)
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:281
bfc006e4:	ae330000 	sw	s3,0(s1)
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:283
bfc006e8:	3c100000 	lui	s0,0x0
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:285
bfc006ec:	3c09bfc0 	lui	t1,0xbfc0
bfc006f0:	25290704 	addiu	t1,t1,1796
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:286
bfc006f4:	3c0a2000 	lui	t2,0x2000
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:287
bfc006f8:	012ac823 	subu	t9,t1,t2
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:288
bfc006fc:	03200008 	jr	t9
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:289
bfc00700:	00000000 	nop
```

报错位从481L 0xbfc006bc后移到了508L 0xbfc006f8。很明显，报错的原因是缺少`subu`指令。因此，先添加几个亟需的指令是当务之急。

`subu`是很好添的，填上之后我们看到下一个错误点在bfc00714 - `lui`。奇怪的是，这是个已经实现了的指令。

```s
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:295
bfc00710:	00000000 	nop
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/start.S:297
bfc00714:	3c19bfc0 	lui	t9,0xbfc0
bfc00718:	27390724 	addiu	t9,t9,1828
```

在看了前面的指令后我发觉他是让我补`jal`指令。有点艰辛：我看了两天才明白它要我把`pc`和8加一起送进`alu`做`add`。接下来一下子到了0x510c:
```s
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/inst/n1_lui.S:8
bfc05104:	24120000 	li	s2,0
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/inst/n1_lui.S:9
bfc05108:	3c0a0001 	lui	t2,0x1
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/inst/n1_lui.S:11
bfc0510c:	24090000 	li	t1,0
/media/sf_nscscc2019/develop/trash/func_test_v0.03/soft/func/inst/n1_lui.S:12
```
恭喜我们进入了第一个测试点。此时我们要补充的是`li`。看它机器码开头是`0x24(0010 0100)`，我突然反应过来：这不tm的addiu的操作码吗？那么实际上这个码是：
```
0010 0100 0000 1001 0000 0000 0000 0000
->
001001 00000 01001 0000000000000000
```
也就是：
```Assembly
addiu t0,t9 0
```

$t_9=t_0+0$ 。
再看报错：
```
[   2337 ns] Error!!!
    reference: PC = 0x9fc05108, wb_rf_wnum = 0x0a, wb_rf_wdata = 0x00010000
    mycpu    : PC = 0xbfc0510c, wb_rf_wnum = 0x09, wb_rf_wdata = 0x00000000
--------------------------------------------------------------
```
`wb_rf_wnum`是期望访问的寄存器，

本次添加了三条指令:
sll、sw、bne

通过主要改动ID段和EX段完成对这三条指令的添加，但是目前仍出现bug需要修改

```
--------------------------------------------------------------

[  14137 ns] Error!!!
    reference: PC = 0x9fc00d54, wb_rf_wnum = 0x09, wb_rf_wdata = 0x0000aaaa

    mycpu    : PC = 0x9fc00d64, wb_rf_wnum = 0x0b, wb_rf_wdata = 0xxxxxxxxx
--------------------------------------------------------------
```

12.11 周六
上午：
完成load相关的错误修改以及解决了mycpu_top.v的错误。
测试点过到PP16
下午：
添加了sub,and,andi,xori,sllv,sra,srav,srl,srlv,nor 10条指令。
测试点过到PP26
修改了addi，andi的立即数符号扩展错误。
测试点到PP36
晚上：继续完成剩余指令的添加

分支指令:
bgez rs>=0 涉及负数 可以使用 (rdata1[31] == 1'b0)直接判断大等于0 
bgtz rs>0 (rdata1[31] == 1'b0 && rdata1 != 0)
blez rs<=0 (rdata1[31] == 1'b0 || rdata1 == 0)
bltz rs<0 (rdata1[31] == 1'b1)
四条分支指令添加后,测试点到达40

bltzal rs<0
bgezal rs>=0
jalr 无条件跳转
三条指令都需要将下下条的指令pc值存入31号寄存器, 选择add操作,pc作为src1,8作为src2再ex段计算即可.

测试点到达43:

```
----[ 983765 ns] Number 8'd43 Functional Test Point PASS!!!
--------------------------------------------------------------
[ 984137 ns] Error!!!
    reference: PC = 0xbfc7d7dc, wb_rf_wnum = 0x15, wb_rf_wdata = 0x00000002
    mycpu    : PC = 0xbfc7d7e4, wb_rf_wnum = 0x02, wb_rf_wdata = 0x00000002
--------------------------------------------------------------
```
下一条需要添加的指令是(移动指令)mflo

增加hi lo 寄存器 
仿照通用寄存器添加数据通路
现在regfile中添加寄存器

完成在各个模块间有关mflo等指令的线的添加

完成hilo存在数据相关问题的数据通路和定向路径的添加

添加了mflo mfhi mtlo mthi 四条指令。

乘除指令会同时写hi lo两个寄存器需要进行修改

添加了乘除指令,并对原先的部分错误进行了修改
```
----[1253335 ns] Number 8'd58 Functional Test Point PASS!!!
--------------------------------------------------------------
[1253747 ns] Error!!!
    reference: PC = 0xbfc371a0, wb_rf_wnum = 0x02, wb_rf_wdata = 0x0000000b
    mycpu    : PC = 0xbfc371a4, wb_rf_wnum = 0x05, wb_rf_wdata = 0x800d6764
```