/* Hosler and Jackson */

`timescale 1ns / 1ps
`default_nettype none

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data, //rs
               input wire [15:0]  i_r2data, //rt
               output wire [15:0] o_result);
   
   //ADD, MUL, SUB, DIV, MOD, AND, NOT, OR, XOR, SLL, SRA, SRL, CONST, HICONST
   wire [15:0] add_sub_result;
   wire [15:0] mul_result;
   wire	[15:0] div_result;
   wire	[15:0] mod_result;
   wire	[15:0] and_result;
   wire	[15:0] not_result;
   wire [15:0] or_result;
   wire	[15:0] xor_result;
   wire	[15:0] sll_result;
   wire	[15:0] sra_result;
   wire	[15:0] srl_result;
   wire	[15:0] const_result;
   wire	[15:0] hiconst_result;

   assign mul_result = i_r1data * i_r2data;

   assign and_result = i_r1data & i_r2data;
   assign not_result = ~i_r1data;
   assign or_result = i_r1data | i_r2data;
   assign xor_result = i_r1data ^ i_r2data; 

    //shifts
    assign sll_result = i_r1data << i_insn[3:0];
    assign sra_result = i_r1data >>> i_insn[3:0];
    assign srl_result = i_r1data >> i_insn[3:0];

   
    //DIV and MOD
    lc4_divider d0(.i_dividend(i_r1data),
 		  .i_divisor(i_r2data),
 		  .o_remainder(mod_result),
 		  .o_quotient(div_result));
   
    //ADD and SUB
    cla16 c0(.a(i_r1data),
 	    .b(i_r2data),
 	    .cin(i_insn[4]),
 	    .sum(add_sub_result));
   
   
endmodule
