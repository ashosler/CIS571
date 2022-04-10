`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

   /*** TODO: Your Code Here ***/
   // wires for the output of each register
   wire [n-1:0] reg0_out;
   wire [2:0] reg0_in;
   wire reg0_we;

   // When registers being written to conflict, B gets priority
   assign reg0_in = (i_rd_B == 3'd0) ? i_wdata_B : i_wdata_A;

   assign reg0_we = (((i_rd_B == 3'd0) & i_rd_we_B) | 
                     ((i_rd_A == 3'd0) & i_rd_we_A));
   
   // Registers instantiated
   Nbit_reg #(n) reg0 (.in(reg0_in),
         .out(reg0_out),
         .clk(clk), .we(reg0_we),
         .gwe(gwe), .rst(rst));
   

   // bypass inputs to outputs should this take conflicts b/w A and B into account??
   assign o_rs_data_A = ((i_rs_A == 3'd0) & ((i_rd_A == 3'd0) & i_rd_we_A)) ? reg0_in :
                        (i_rs_A == 3'd0) ? reg0_out;

   // Nbit_reg #(n) reg1 (.in(),
   //       .out(),
   //       .clk(clk), .we(),
   //       .gwe(gwe), .rst(rst));
   // Nbit_reg #(n) reg2 (.in(),
   //       .out(),
   //       .clk(clk), .we(),
   //       .gwe(gwe), .rst(rst));
   // Nbit_reg #(n) reg3 (.in(),
   //       .out(),
   //       .clk(clk), .we(),
   //       .gwe(gwe), .rst(rst));
   // Nbit_reg #(n) reg4 (.in(),
   //       .out(),
   //       .clk(clk), .we(),
   //       .gwe(gwe), .rst(rst));
   // Nbit_reg #(n) reg5 (.in(),
   //       .out(), 
   //       .clk(clk), .we(),
   //       .gwe(gwe), .rst(rst));
   // Nbit_reg #(n) reg6 (.in(), 
   //       .out(), 
   //       .clk(clk), .we(),
   //       .gwe(gwe), .rst(rst));
   // Nbit_reg #(n) reg7 (.in(), 
   //       .out(), 
   //       .clk(clk), .we(),
   //       .gwe(gwe), .rst(rst));
endmodule
