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
