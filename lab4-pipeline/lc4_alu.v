/* 
Names: Allison Hosler and Antaures Jackson
Pennkeys: ashosler and ajj4311
 */

 `timescale 1ns / 1ps
 `default_nettype none
 
 module lc4_alu(input  wire [15:0] i_insn,
                input wire [15:0]  i_pc,
                input wire [15:0]  i_r1data,
                input wire [15:0]  i_r2data,
                output wire [15:0] o_result);
 
 
    wire [3:0] op = i_insn[15:12];
    
    //AND, NOT, OR, XOR
    wire [15:0] and_result;
 
    wire	[15:0] not_result;
    wire [15:0] or_result;
    wire	[15:0] xor_result;
    assign and_result = i_insn[5] == 1'b0 ? i_r1data & i_r2data : //AND
                    i_insn[4] == 1'b0 ? i_r1data & (16'b0 | i_insn[4:0]): //ANDI pos
                    i_r1data & ((16'hffff << 5) | i_insn[4:0]); //ANDI neg
    assign not_result = ~i_r1data;
    assign or_result = i_r1data | i_r2data;
    assign xor_result = i_r1data ^ i_r2data;
    
    //CONST, HICONST
    wire	[15:0] const_result;
    wire	[15:0] hiconst_result;
 
    assign const_result = i_insn[8] == 1'b0 ? 16'b0 | i_insn[8:0] : (16'hffff << 9) | i_insn[8:0];
    assign hiconst_result = (i_r1data & 16'hff) | (i_insn[7:0] << 8);
    
    //SLL, SRA, SRL
    wire [15:0] sll_result;
    wire [15:0] sra_result;
    wire [15:0] srl_result;
    assign sll_result = i_r1data << i_insn[3:0];
    assign sra_result = $signed(i_r1data) >>> i_insn[3:0];
    assign srl_result = i_r1data >> i_insn[3:0];
 
 
    //MUL
    wire [15:0] mul_result;
    assign mul_result = i_r1data * i_r2data;   
    
 
    //DIV, MOD
    wire [15:0] div_result;
    wire [15:0] mod_result;
    lc4_divider d0(.i_dividend(i_r1data),
               .i_divisor(i_r2data),
               .o_remainder(mod_result),
               .o_quotient(div_result));
    
    //ADD, (SUB, ADDI, LDR, STR, NOP_to_BRnzp, CMP_to_CMPIU, JMP)
    wire [15:0] add_result;
    wire [15:0] add_a;
    wire [15:0] add_b;
    wire add_cin;
    assign add_a = op == 4'b0001 ? i_r1data : //ADD, SUB, ADDI
               op == 4'b0110 ? i_r1data : //LDR
               op == 4'b0111	? i_r1data : //STR
               op == 4'b0000 ? i_pc : //NOP_to_BRnzp
               op == 4'b0010 ? i_r1data : //CMP_to_CMPIU
               op == 4'b1100 ? i_pc : //JMP
               16'b0;
    assign add_b = (op == 4'b0001) & (i_insn[5:3] == 3'b000) ? i_r2data : //ADD
               (op == 4'b0001) & (i_insn[5:3] == 3'b010) ? ~i_r2data : //SUB
               (op == 4'b0001) & (i_insn[5] == 1'b1) & (i_insn[4] == 1'b0) ? 16'b0 | i_insn[4:0] : //ADDI pos
               (op == 4'b0001) & (i_insn[5] == 1'b1) & (i_insn[4] == 1'b1) ? (16'hffff << 5) | i_insn[4:0] : //ADDI neg 
               (op == 4'b0110) & (i_insn[5] == 1'b0) ? 16'b0 | i_insn[5:0] : //LDR pos
               (op == 4'b0110) & (i_insn[5] == 1'b1) ? (16'hffff << 6) | i_insn[5:0] : //LDR neg
               (op == 4'b0111) & (i_insn[5] == 1'b0) ? 16'b0 | i_insn[5:0] : //STR pos
               (op == 4'b0111) & (i_insn[5] == 1'b1) ? (16'hffff << 6) | i_insn[5:0] : //STR neg
               (op == 4'b0000) & (i_insn[8] == 1'b0) ? 16'b0 | i_insn[8:0] : //NOP_to_BRnzp pos
               (op == 4'b0000) & (i_insn[8] == 1'b1) ? (16'hffff << 9) | i_insn[8:0] : //NOP_to_BRnzp neg
               (op == 4'b0010) & (i_insn[8] == 1'b0) ? ~i_r2data : //CMP, CMPU
               (op == 4'b0010) & (i_insn[8:7] == 2'b11) ? ~(16'b0 | i_insn[6:0]) : //CMPIU
               (op == 4'b0010) & (i_insn[8:7] == 2'b10) & (i_insn[6] == 1'b0) ? ~(16'b0 | i_insn[6:0]) : //CMPI pos
               (op == 4'b0010) & (i_insn[8:7] == 2'b10) & (i_insn[6] == 1'b1) ? ~((16'hffff << 7) | i_insn[6:0]) : //CMPIneg
               
               (op == 4'b1100) & (i_insn[10] == 1'b0) ? 16'b0 | i_insn[10:0] ://JMP pos
               (op == 4'b1100) & (i_insn[10] == 1'b1) ? (16'hffff << 11) | i_insn[10:0] ://JMP neg
               16'b0;
    assign add_cin = (op == 4'b0001) & (i_insn[5:3] == 3'b010) ? 1'b1 : //SUB
                 (op == 4'b0000) ? 1'b1 : //NOP_to_BRnzp
                 (op == 4'b0010) ? 1'b1 : //CMP_to_CMPIU
                 (op == 4'b1100) ? 1'b1 : //JMP
                 1'b0; //STR, LDR, ADD, ADDI
    cla16 c0(.a(add_a),
           .b(add_b),
           .cin(add_cin),
           .sum(add_result));
 
    
 
    //JMPR, JSR, JSRR, RTI, TRAP
    wire [15:0] jmpr_result = i_r1data;
    wire [15:0] jsr_result = (i_pc & 16'b1000000000000000) | (i_insn[10:0] <<4) ; //signed tho?
    wire [15:0] jsrr_result = i_r1data;
    wire [15:0] rti_result = i_r1data;
    wire [15:0] trap_result = 16'b1000000000000000 | i_insn[7:0];
 
    //CMP
    wire [15:0] cmp_result;
    wire [15:0] cmpu_result;
    wire [15:0] cmpi_result;
    wire [15:0] cmpiu_result;
    assign cmp_result = add_result == 16'b0 ? 16'b0 :
                    (i_r1data[15] == 1'b0) & (i_r2data[15] == 1'b1) ? 16'b1 : //positive - negative = positive
                    (i_r1data[15] == 1'b1) & (i_r2data[15] == 1'b0) ? 16'hffff : //negative - positive = negative
                    add_result[15] == 1'b0 ? 16'b1 :
                        16'hffff;
 
    assign cmpu_result = i_r1data == i_r2data ? 16'b0 :
                   i_r1data > i_r2data ? 16'b1 :
                   16'hffff; 
    
    assign cmpi_result = add_result == 16'b0 ? 16'b0 :
                   (i_r1data[15] == 1'b0) & (i_insn[6] == 1'b1) ? 16'b1 : //positive - negative = positive               
                   (i_r1data[15] == 1'b1) & (i_insn[6] == 1'b0) ? 16'hffff : //negative - positive = negative 
                   add_result[15] == 1'b0 ? 16'b1 :
                   16'hffff;
 
    assign cmpiu_result = i_r1data == (16'b0 | i_insn[6:0]) ? 16'b0 :
                          i_r1data > (16'b0 | i_insn[6:0]) ? 16'b1 :
                          16'hffff;
                    
 //assign op outputs
    wire [15:0] add_to_div;	       
    wire [15:0] jsrr_to_jsr;
    wire [15:0] and_to_xor;
    wire [15:0] sll_to_mod;
    wire [15:0] jmpr_to_jmp;
    wire [15:0] cmp_to_cmpiu;
    assign add_to_div = i_insn[5:3] == 3'b001 ? mul_result:
                     i_insn[5:3] == 3'b011 ? div_result:
                    add_result; //ADD, SUB, ADDI
    assign jsrr_to_jsr = i_insn[11] == 1'b0 ? jsrr_result :
                   jsr_result;
    assign and_to_xor = i_insn[5:3] == 3'b001 ? not_result :
                    i_insn[5:3] == 3'b010 ? or_result :
                    i_insn[5:3] == 3'b011 ? xor_result :
                    and_result; //AND, ANDI
    assign sll_to_mod = i_insn[5:4] == 2'b00 ? sll_result :
                    i_insn[5:4] == 2'b01 ? sra_result :
                    i_insn[5:4] == 2'b10 ? srl_result :
                    mod_result;
    assign jmpr_to_jmp = i_insn[11] == 1'b0 ? jmpr_result :
                   add_result; //JMP
    assign  cmp_to_cmpiu = i_insn[8:7] == 2'b00 ? cmp_result :
                     i_insn[8:7] == 2'b01 ? cmpu_result :
                     i_insn[8:7] == 2'b10 ? cmpi_result :
                     cmpiu_result;
    
    //assign output
    assign o_result = op == 4'b0000 ? add_result : //(NOP_toBRnzp)
                  op == 4'b0001 ? add_to_div : //ADD, MUL, SUB, DIV, ADDI
                  op == 4'b0010 ? cmp_to_cmpiu : //CMP, CMPU, CMPI, CMPIU
                  op == 4'b0100 ? jsrr_to_jsr : //JSRR, JSR
                  op == 4'b0101 ? and_to_xor : //AND, NOT, OR, XOR, ANDI
                  op == 4'b0110 ? add_result : //(LDR)
                  op	== 4'b0111 ? add_result : //(STR)
                  op == 4'b1000 ? rti_result : 
                  op == 4'b1001 ? const_result :
                  op == 4'b1010 ? sll_to_mod : //SLL, SRA, SRL, MOD
                  op == 4'b1100 ? jmpr_to_jmp : //JMPR, JMP
                  op == 4'b1101 ? hiconst_result :
                  op == 4'b1111 ? trap_result :
                  16'b0;
    
    
 
 endmodule
 