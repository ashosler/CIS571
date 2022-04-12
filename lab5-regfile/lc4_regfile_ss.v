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
   // wires for each register
//    wire [n-1:0] reg0_out, reg1_out, reg2_out, reg3_out, reg4_out, reg5_out, reg6_out, reg7_out;
//    wire [n-1:0] reg0_in, reg1_in, reg2_in, reg3_in, reg4_in, reg5_in, reg6_in, reg7_in;
//    wire reg0_we, reg1_we, reg2_we, reg3_we, reg4_we, reg5_we, reg6_we, reg7_we;

//    // When registers being written to conflict, B gets priority
//    assign reg0_in = (i_rd_B == 3'd0) ? i_wdata_B : i_wdata_A;
//    assign reg1_in = (i_rd_B == 3'd1) ? i_wdata_B : i_wdata_A;
//    assign reg2_in = (i_rd_B == 3'd2) ? i_wdata_B : i_wdata_A;
//    assign reg3_in = (i_rd_B == 3'd3) ? i_wdata_B : i_wdata_A;
//    assign reg4_in = (i_rd_B == 3'd4) ? i_wdata_B : i_wdata_A;
//    assign reg5_in = (i_rd_B == 3'd5) ? i_wdata_B : i_wdata_A;
//    assign reg6_in = (i_rd_B == 3'd6) ? i_wdata_B : i_wdata_A;
//    assign reg7_in = (i_rd_B == 3'd7) ? i_wdata_B : i_wdata_A;

//    assign reg0_we = (((i_rd_B == 3'd0) & i_rd_we_B) | 
//                      ((i_rd_A == 3'd0) & i_rd_we_A));
//    assign reg1_we = (((i_rd_B == 3'd1) & i_rd_we_B) | 
//                      ((i_rd_A == 3'd1) & i_rd_we_A));
//    assign reg2_we = (((i_rd_B == 3'd2) & i_rd_we_B) | 
//                      ((i_rd_A == 3'd2) & i_rd_we_A));
//    assign reg3_we = (((i_rd_B == 3'd3) & i_rd_we_B) | 
//                      ((i_rd_A == 3'd3) & i_rd_we_A));
//    assign reg4_we = (((i_rd_B == 3'd4) & i_rd_we_B) | 
//                      ((i_rd_A == 3'd4) & i_rd_we_A));
//    assign reg5_we = (((i_rd_B == 3'd5) & i_rd_we_B) | 
//                      ((i_rd_A == 3'd5) & i_rd_we_A));
//    assign reg6_we = (((i_rd_B == 3'd6) & i_rd_we_B) | 
//                      ((i_rd_A == 3'd6) & i_rd_we_A));
//    assign reg7_we = (((i_rd_B == 3'd7) & i_rd_we_B) | 
//                      ((i_rd_A == 3'd7) & i_rd_we_A));


//    // Registers instantiated
//    Nbit_reg #(n) reg0 (.in(reg0_in),
//          .out(reg0_out),
//          .clk(clk), .we(reg0_we),
//          .gwe(gwe), .rst(rst));
//    Nbit_reg #(n) reg1 (.in(reg1_in),
//          .out(reg1_out),
//          .clk(clk), .we(reg1_we),
//          .gwe(gwe), .rst(rst));
//    Nbit_reg #(n) reg2 (.in(reg2_in),
//          .out(reg2_out),
//          .clk(clk), .we(reg2_we),
//          .gwe(gwe), .rst(rst));
//    Nbit_reg #(n) reg3 (.in(reg3_in),
//          .out(reg3_out),
//          .clk(clk), .we(reg3_we),
//          .gwe(gwe), .rst(rst));
//    Nbit_reg #(n) reg4 (.in(reg4_in),
//          .out(reg4_out),
//          .clk(clk), .we(reg4_we),
//          .gwe(gwe), .rst(rst));
//    Nbit_reg #(n) reg5 (.in(reg5_in),
//          .out(reg5_out), 
//          .clk(clk), .we(reg5_we),
//          .gwe(gwe), .rst(rst));
//    Nbit_reg #(n) reg6 (.in(reg6_in), 
//          .out(reg6_out), 
//          .clk(clk), .we(reg6_we),
//          .gwe(gwe), .rst(rst));
//    Nbit_reg #(n) reg7 (.in(reg7_in), 
//          .out(reg7_out), 
//          .clk(clk), .we(reg7_we),
//          .gwe(gwe), .rst(rst));

//          // bypass inputs to outputs should this take conflicts b/w A and B into account??
//          /* INSN in b piep */
//    assign o_rs_data_A = ((i_rs_A == 3'd0) && reg0_we) ? reg0_in :
//                          (i_rs_A == 3'd0)  ? reg0_out :
//                          ((i_rs_A == 3'd1) && reg1_we) ? reg1_in :
//                          (i_rs_A == 3'd1)  ? reg1_out :
//                          ((i_rs_A == 3'd2) & reg2_we) ? reg2_in :
//                          (i_rs_A == 3'd2)  ? reg2_out :
//                          ((i_rs_A == 3'd3) & reg3_we) ? reg3_in :
//                          (i_rs_A == 3'd3)  ? reg3_out :
//                          ((i_rs_A == 3'd4) & reg4_we) ? reg4_in :
//                          (i_rs_A == 3'd4)  ? reg4_out :
//                          ((i_rs_A == 3'd5) & reg5_we) ? reg5_in :
//                          (i_rs_A == 3'd5)  ? reg5_out :
//                          ((i_rs_A == 3'd6) & reg6_we) ? reg6_in :
//                          (i_rs_A == 3'd6)  ? reg6_out :
//                          ((i_rs_A == 3'd7) & reg7_we) ? reg7_in :
//                          reg7_out;

//    assign o_rs_data_B = ((i_rs_B == 3'd0) & reg0_we) ? reg0_in :
//                         (i_rs_B == 3'd0) ? reg0_out :
//                         ((i_rs_B == 3'd1) & reg1_we) ? reg1_in :
//                         (i_rs_B == 3'd1) ? reg1_out :
//                         ((i_rs_B == 3'd2) & reg2_we) ? reg2_in :
//                         (i_rs_B == 3'd2) ? reg2_out :
//                         ((i_rs_B == 3'd3) & reg3_we) ? reg3_in :
//                         (i_rs_B == 3'd3) ? reg3_out :
//                         ((i_rs_B == 3'd4) & reg4_we) ? reg4_in :
//                         (i_rs_B == 3'd4) ? reg4_out :
//                         ((i_rs_B == 3'd5) & reg5_we) ? reg5_in :
//                         (i_rs_B == 3'd5) ? reg5_out :
//                         ((i_rs_B == 3'd6) & reg6_we) ? reg6_in :
//                         (i_rs_B == 3'd6) ? reg6_out :
//                         ((i_rs_B == 3'd7) & reg7_we) ? reg7_in :
//                         reg7_out;

//    assign o_rt_data_A = ((i_rt_A == 3'd0) & reg0_we) ? reg0_in :
//                         (i_rt_A == 3'd0) ? reg0_out :
//                         ((i_rt_A == 3'd1) & reg1_we) ? reg1_in :
//                         (i_rt_A == 3'd1) ? reg1_out : 
//                         ((i_rt_A == 3'd2) & reg2_we) ? reg2_in :
//                         (i_rt_A == 3'd2) ? reg2_out : 
//                         ((i_rt_A == 3'd3) & reg3_we) ? reg3_in :
//                         (i_rt_A == 3'd3) ? reg3_out : 
//                         ((i_rt_A == 3'd4) & reg4_we) ? reg4_in :
//                         (i_rt_A == 3'd4) ? reg4_out : 
//                         ((i_rt_A == 3'd5) & reg5_we) ? reg5_in :
//                         (i_rt_A == 3'd5) ? reg5_out : 
//                         ((i_rt_A == 3'd6) & reg6_we) ? reg6_in :
//                         (i_rt_A == 3'd6) ? reg6_out : 
//                         ((i_rt_A == 3'd7) & reg7_we) ? reg7_in :
//                         reg7_out;

//    assign o_rt_data_B = ((i_rt_B == 3'd0) & reg0_we) ? reg0_in :
//                         (i_rt_B == 3'd0) ? reg0_out :
//                         ((i_rt_B == 3'd1) & reg1_we) ? reg1_in :
//                         (i_rt_B == 3'd1) ? reg1_out :
//                         ((i_rt_B == 3'd2) & reg2_we) ? reg2_in :
//                         (i_rt_B == 3'd2) ? reg2_out :
//                         ((i_rt_B == 3'd3) & reg3_we) ? reg3_in :
//                         (i_rt_B == 3'd3) ? reg3_out :
//                         ((i_rt_B == 3'd4) & reg4_we) ? reg4_in :
//                         (i_rt_B == 3'd4) ? reg4_out :
//                         ((i_rt_B == 3'd5) & reg5_we) ? reg5_in :
//                         (i_rt_B == 3'd5) ? reg5_out :
//                         ((i_rt_B == 3'd6) & reg6_we) ? reg6_in :
//                         (i_rt_B == 3'd6) ? reg6_out :
//                         ((i_rt_B == 3'd7) & reg7_we) ? reg7_in :
//                         reg7_out;

    wire [n-1:0] output_data[8:0];
    genvar i; 
    generate 
          for (i = 0; i < 8; i = i + 1) begin
            Nbit_reg #(n) register (.out(output_data[i]), .in((i_rd_B == i) & i_rd_we_B ? i_wdata_B : i_wdata_A), .clk(clk), 
                        .we((i_rd_A == i) & i_rd_we_A || (i_rd_B == i) & i_rd_we_B), 
                        .gwe(gwe), .rst(rst));
          end     
    endgenerate

    assign o_rs_data_A = (i_rd_B == i_rs_A) & i_rd_we_B ? i_wdata_B :
                         (i_rd_A == i_rs_A) & i_rd_we_A ? i_wdata_A :
                         output_data[i_rs_A];

    assign o_rs_data_B = (i_rd_B == i_rs_B) & i_rd_we_B ? i_wdata_B :
                        (i_rd_A == i_rs_B) & i_rd_we_A ? i_wdata_A :
                        output_data[i_rs_B];

   assign o_rt_data_A = (i_rd_B == i_rt_A) & i_rd_we_B ? i_wdata_B :
                        (i_rd_A == i_rt_A) & i_rd_we_A ? i_wdata_A :
                        output_data[i_rt_A];

   assign o_rt_data_B = (i_rd_B == i_rt_B) & i_rd_we_B ? i_wdata_B :
                       (i_rd_A == i_rt_B) & i_rd_we_A ? i_wdata_A :
                       output_data[i_rt_B]; 



endmodule
