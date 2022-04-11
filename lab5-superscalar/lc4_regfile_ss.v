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

   // Registers // 7365/8000 for the register file need to find bug
    assign o_rs_data_A = ((i_rs_A == 3'd0) && ((i_rd_A == 3'd0) && i_rd_we_A)) ? reg0_in :
    (i_rs_A == 3'd0)  ? reg0_out :
    ((i_rs_A == 3'd1) && ((i_rd_A == 3'd1) && i_rd_we_A)) ? reg1_in :
    (i_rs_A == 3'd1)  ? reg1_out :
    ((i_rs_A == 3'd2) & ((i_rd_A == 3'd2) & i_rd_we_A)) ? reg2_in :
    (i_rs_A == 3'd2)  ? reg2_out :
    ((i_rs_A == 3'd3) & ((i_rd_A == 3'd3) & i_rd_we_A)) ? reg3_in :
    (i_rs_A == 3'd3)  ? reg3_out :
    ((i_rs_A == 3'd4) & ((i_rd_A == 3'd4) & i_rd_we_A)) ? reg4_in :
    (i_rs_A == 3'd4)  ? reg4_out :
    ((i_rs_A == 3'd5) & ((i_rd_A == 3'd5) & i_rd_we_A)) ? reg5_in :
    (i_rs_A == 3'd5)  ? reg5_out :
    ((i_rs_A == 3'd6) & ((i_rd_A == 3'd6) & i_rd_we_A)) ? reg6_in :
    (i_rs_A == 3'd6)  ? reg6_out :
    ((i_rs_A == 3'd7) & ((i_rd_A == 3'd7) & i_rd_we_A)) ? reg7_in :
    reg7_out;

assign o_rs_data_B = ((i_rs_B == 3'd0) & ((i_rd_B == 3'd0) & i_rd_we_B)) ? reg0_in :
   (i_rs_B == 3'd0) ? reg0_out :
   ((i_rs_B == 3'd1) & ((i_rd_B == 3'd1) & i_rd_we_B)) ? reg1_in :
   (i_rs_B == 3'd1) ? reg1_out :
   ((i_rs_B == 3'd2) & ((i_rd_B == 3'd2) & i_rd_we_B)) ? reg2_in :
   (i_rs_B == 3'd2) ? reg2_out :
   ((i_rs_B == 3'd3) & ((i_rd_B == 3'd3) & i_rd_we_B)) ? reg3_in :
   (i_rs_B == 3'd3) ? reg3_out :
   ((i_rs_B == 3'd4) & ((i_rd_B == 3'd4) & i_rd_we_B)) ? reg4_in :
   (i_rs_B == 3'd4) ? reg4_out :
   ((i_rs_B == 3'd5) & ((i_rd_B == 3'd5) & i_rd_we_B)) ? reg5_in :
   (i_rs_B == 3'd5) ? reg5_out :
   ((i_rs_B == 3'd6) & ((i_rd_B == 3'd6) & i_rd_we_B)) ? reg6_in :
   (i_rs_B == 3'd6) ? reg6_out :
   ((i_rs_B == 3'd7) & ((i_rd_B == 3'd7) & i_rd_we_B)) ? reg7_in :
   reg7_out;

assign o_rt_data_A = ((i_rt_A == 3'd0) & ((i_rd_A == 3'd0) & i_rd_we_A)) ? reg0_in :
   (i_rt_A == 3'd0) ? reg0_out :
   ((i_rt_A == 3'd1) & ((i_rd_A == 3'd1) & i_rd_we_A)) ? reg1_in :
   (i_rt_A == 3'd1) ? reg1_out : 
   ((i_rt_A == 3'd2) & ((i_rd_A == 3'd2) & i_rd_we_A)) ? reg2_in :
   (i_rt_A == 3'd2) ? reg2_out : 
   ((i_rt_A == 3'd3) & ((i_rd_A == 3'd3) & i_rd_we_A)) ? reg3_in :
   (i_rt_A == 3'd3) ? reg3_out : 
   ((i_rt_A == 3'd4) & ((i_rd_A == 3'd4) & i_rd_we_A)) ? reg4_in :
   (i_rt_A == 3'd4) ? reg4_out : 
   ((i_rt_A == 3'd5) & ((i_rd_A == 3'd5) & i_rd_we_A)) ? reg5_in :
   (i_rt_A == 3'd5) ? reg5_out : 
   ((i_rt_A == 3'd6) & ((i_rd_A == 3'd6) & i_rd_we_A)) ? reg6_in :
   (i_rt_A == 3'd6) ? reg6_out : 
   ((i_rt_A == 3'd7) & ((i_rd_A == 3'd7) & i_rd_we_A)) ? reg7_in :
   reg7_out;

assign o_rt_data_B = ((i_rt_B == 3'd0) & ((i_rd_B == 3'd0) & i_rd_we_B)) ? reg0_in :
   (i_rt_B == 3'd0) ? reg0_out :
   ((i_rt_B == 3'd1) & ((i_rd_B == 3'd1) & i_rd_we_B)) ? reg1_in :
   (i_rt_B == 3'd1) ? reg1_out :
   ((i_rt_B == 3'd2) & ((i_rd_B == 3'd2) & i_rd_we_B)) ? reg2_in :
   (i_rt_B == 3'd2) ? reg2_out :
   ((i_rt_B == 3'd3) & ((i_rd_B == 3'd3) & i_rd_we_B)) ? reg3_in :
   (i_rt_B == 3'd3) ? reg3_out :
   ((i_rt_B == 3'd4) & ((i_rd_B == 3'd4) & i_rd_we_B)) ? reg4_in :
   (i_rt_B == 3'd4) ? reg4_out :
   ((i_rt_B == 3'd5) & ((i_rd_B == 3'd5) & i_rd_we_B)) ? reg5_in :
   (i_rt_B == 3'd5) ? reg5_out :
   ((i_rt_B == 3'd6) & ((i_rd_B == 3'd6) & i_rd_we_B)) ? reg6_in :
   (i_rt_B == 3'd6) ? reg6_out :
   ((i_rt_B == 3'd7) & ((i_rd_B == 3'd7) & i_rd_we_B)) ? reg7_in :
   reg7_out;

endmodule
