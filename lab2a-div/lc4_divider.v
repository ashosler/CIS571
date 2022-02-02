/* 
Names: Allison Hosler and Antaures Jackson
Pennkeys: ashosler and ajj4311
 */

`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);
   genvar i;
   wire [15:0] r_i [16:0];
   wire [15:0] dn_i [16:0];
   wire [15:0] q_i [16:0];
   assign r_i[0] = 16'b0;
   assign dn_i[0] = i_dividend;
   assign q_i[0] = 16'b0;
   
   generate
   for (i = 1; i <= 16; i = i + 1) begin
      lc4_divider_one_iter d0(.i_dividend(dn_i[i-1]),
			      .i_divisor(i_divisor),
                              .i_remainder(r_i[i-1]),
                              .i_quotient(q_i[i-1]),
                              .o_dividend(dn_i[i]),
                              .o_remainder(r_i[i]),
                              .o_quotient(q_i[i]));
   end
   endgenerate
   assign o_remainder = i_divisor === 0 ? 16'b0 : r_i[16];                                                                                   
   assign o_quotient = i_divisor === 0 ? 16'b0 : q_i[16];
endmodule // lc4_divider

module lc4_divider_one_iter(input wire [15:0] i_dividend,
                            input wire [15:0] i_divisor,
                            input wire [15:0] i_remainder,
                            input wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);
   wire [15:0] r_shift;
   wire [15:0] r_sub;
   wire select;

   assign r_shift = i_remainder << 1 | i_dividend >> 15;
   assign select = r_shift < i_divisor;
   assign r_sub = r_shift - i_divisor;
      
   assign o_quotient = select ? (i_quotient << 1) : (i_quotient << 1 | 16'b1);   
   assign o_remainder = select ? r_shift : r_sub;
   assign o_dividend = i_dividend << 1;   
endmodule
