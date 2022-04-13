`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );

   /***  YOUR CODE HERE ***/
   assign led_data = switch_data;

   wire [15:0] pc;               // Current program counter (read out from pc_reg)
   wire [15:0] next_pc;          // Next program counter (computed and fed into pc_reg)

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(WB_next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   // Program counter for pipe B instruction
   wire [15:0] pc_B;
   cla16 c0 (.a(pc), .b(16'b0), .cin(1'b1), .sum(pc_B));

   // =================================== DECODE Stage ===============================================
   // *************** [Fetch to] Decode Register ********************
   wire [15:0] DEC_insn_A, DEC_insn_B, DEC_pc_A, DEC_pc_B;

   Nbit_reg #(16) IFID_insn_A(.out(DEC_insn_A), .in(i_cur_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IFID_insn_B(.out(DEC_insn_B), .in(i_cur_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IFID_pc_A(.out(DEC_pc_A), .in(pc), .we(1'b1), .clk(clk), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IFID_pc_B(.out(DEC_pc_B), .in(pc_B), .we(1'b1), .clk(clk), .gwe(gwe), .rst(rst));

   // *************** END Decode Register ***************************

   // Instantiate decoders
   wire [2:0] r1sel_A, r2sel_A, wsel_A;
   wire r1re_A, r2re_A, regfile_we_A, nzp_we_A, select_pc_plus_one_A,
        is_load_A, is_store_A, is_branch_A, is_control_insn_A;
   lc4_decoder Decoder_A (.insn(DEC_insn_A), .r1sel(r1sel_A), .r2sel(r2sel_A), .r2re(r2re_A),
                        .wsel(wsel_A), .regfile_we(regfile_we_A), .nzp_we(nzp_we_A),
                        .select_pc_plus_one(select_pc_plus_one_A), .is_load(is_load_A),
                        .is_store(is_store_A), .is_branch(is_branch_A), .is_control_insn(is_control_insn_A));
   
   wire [2:0] r1sel_B, r2sel_B, wsel_B;
   wire r1re_B, r2re_B, regfile_we_B, nzp_we_B, select_pc_plus_one_B,
         is_load_B, is_store_B, is_branch_B, is_control_insn_B;
   lc4_decoder Decoder_B (.insn(DEC_insn_B), .r1sel(r1sel_B), .r2sel(r2sel_B), .r2re(r2re_B),
                          .wsel(wsel_B), .regfile_we(regfile_we_B), .nzp_we(nzp_we_B),
                          .select_pc_plus_one(select_pc_plus_one_B), .is_load(is_load_B),
                          .is_store(is_store_B), .is_branch(is_branch_B), .is_control_insn(is_control_insn_B));

   // Register Data Wires
   wire [15:0] 	 rs_data_A, rt_data_A, rs_data_B, rt_data_B;
   wire [15:0]     wdata_A, wdata_B;

   /* superscalar stall happens when insn DA and DB */
      
   // Instantiate Register File
   lc4_regfile_ss Register_ss (.clk(clk), .gwe(gwe), .rst(rst),
                  .i_rs_A(r1sel_A), .o_rs_data_A(rs_data_A), .i_rt_A(r2sel_A), .o_rt_data_A(rt_data_A),
                  .i_rs_B(r2sel_B), .o_rs_data_B(rs_data_B), .i_rt_B(r2sel_B), .o_rt_data_B(rt_data_B),
                  .i_rd_A(wsel_A), .i_wdata_A(wdata_A), .i_rd_we_A(regfile_we_A),
                  .i_rd_B(wsel_B), .i_wdata_B(wdata_B), .i_rd_we_B(regfile_we_B)); // wdata_A and B should be plugged from writeback

   // ================================== EXECUTE Stage ================================================
   // ******************************* [Decode to] EXECUTE Register ************************************
   wire [15:0] EX_insn_A, EX_insn_B, EX_pc_A, EX_pc_B, EX_rs_data_A, EX_rs_data_B, EX_rt_data_A, EX_rt_data_B;

   Nbit_reg #(16) IDEX_insn_A(.out(EX_insn_A), .in(DEC_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IDEX_insn_B(.out(EX_insn_B), .in(DEC_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IDEX_pc_A(.out(EX_pc_A), .in(DEC_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IDEX_pc_B(.out(EX_pc_B), .in(DEC_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IDEX_rs_data_A(.out(EX_rs_data_A), .in(rs_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IDEX_rs_data_B(.out(EX_rs_data_B), .in(rs_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IDEX_rt_data_A(.out(EX_rt_data_A), .in(rt_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire EX_is_load_A, EX_nzp_we_A, EX_is_branch_A, EX_is_store_A, EX_select_pc_plus_one_A, EX_is_control_insn_A,
        EX_is_load_B, EX_nzp_we_B, EX_is_branch_B, EX_is_store_B, EX_select_pc_plus_one_B, EX_is_control_insn_B;

   Nbit_reg #(1) IDEX_is_load_A(.out(EX_is_load_A), .in(is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_nzp_we_A(.out(EX_nzp_we_A), .in(nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_is_branch_A(.out(EX_is_branch_A), .in(is_branch_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_is_store_A(.out(EX_is_store_A), .in(is_store_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_select_pc_plus_one_A(.out(EX_select_pc_plus_one_A), .in(select_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_is_control_A(.out(EX_is_control_insn_A), .in(is_control_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
   Nbit_reg #(1) IDEX_is_load_B(.out(EX_is_load_B), .in(is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_nzp_we_B(.out(EX_nzp_we_B), .in(nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_is_branch_B(.out(EX_is_branch_B), .in(is_branch_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_is_store_B(.out(EX_is_store_B), .in(is_store_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) IDEX_select_pc_plus_one_B(.out(EX_select_pc_plus_one_B), .in(select_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 
   Nbit_reg #(1) IDEX_is_control_B(.out(EX_is_control_insn_B), .in(is_control_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // *********************************** END EXECUTE Register ****************************************
                        
   // Instantiate ALUs
   wire [15:0] alu_result_A, alu_result_B;                                            
   lc4_alu ALU_A (.i_insn(EX_insn_A), .i_pc(EX_pc_A), .i_r1data(EX_rs_data_A),
                  .i_r2data(EX_rt_data_A), .o_result(alu_result_A));
   lc4_alu ALU_B (.i_insn(EX_insn_B), .i_pc(EX_pc_B), .i_r1data(EX_rs_data_B),
                  .i_r2data(EX_rt_data_B), .o_result(alu_result_B));

   // Calculate incremented pc's
   wire [15:0] pc_plus_two_A, pc_plus_two_B;
   cla16 PC_Incrementer_A (.a(EX_pc_A), .b(16'h0001), .cin(1'b1), .sum(pc_plus_two_A));
   cla16 PC_Incrementer_B (.a(EX_pc_B), .b(16'h0001), .cin(1'b1), .sum(pc_plus_two_B));

   // NZP Registers (CMPs nzp_we) 
   wire [2:0] 		nzp_A, nzp_in_A, nzp_B, nzp_in_B;
   wire [15:0] 		nzp_data_A, nzp_data_B;
   assign nzp_data_A = EX_is_load_A ? i_cur_dmem_data :             // where is dmem data coming from?
                    EX_insn_A[15:12] == 4'b1111 ? pc_plus_two_A : //TRAP (or should it be all control insn?)
                    alu_result_A;
   assign nzp_in_A = nzp_data_A == 16'b0 ? 3'b010 :
                   nzp_data_A[15] == 1'b0 ? 3'b001 :
                   3'b100;
   Nbit_reg #(3) NZP_Reg_A (.in(nzp_in_A), .out(nzp_A), .clk(clk), .we(EX_nzp_we_A), 
                          .gwe(gwe), .rst(rst));

   assign nzp_data_B = EX_is_load_B ? i_cur_dmem_data :             // where is dmem data coming from?
                       (EX_insn_B[15:12] == 4'b1111) ? pc_plus_two_B : //TRAP (or should it be all control insn?)
                       alu_result_B;
   assign nzp_in_B = (nzp_data_B == 16'b0) ? 3'b010 :
                     (nzp_data_B[15] == 1'b0) ? 3'b001 :
                     3'b100;
   Nbit_reg #(3) NZP_Reg_B (.in(nzp_in_B), .out(nzp_B), .clk(clk), .we(EX_nzp_we_B), 
                          .gwe(gwe), .rst(rst));

   // Branch Units
   wire	is_true_branch_A, is_true_branch_B;
   wire [2:0] branch_type_A = EX_insn_A[11:9];
   assign is_true_branch_A = (nzp_A == 3'b010) & (branch_type_A[1] == 1'b1) ? 1'b1: //z
                             (nzp_A == 3'b001) & (branch_type_A[0] == 1'b1) ? 1'b1: //p
                             (nzp_A == 3'b100) & (branch_type_A[2] == 1'b1) ? 1'b1: //n
                             1'b0;
   wire [2:0] branch_type_B = EX_insn_B[11:9];
   assign is_true_branch_B = (nzp_B == 3'b010) & (branch_type_B[1] == 1'b1) ? 1'b1: //z
                             (nzp_B == 3'b001) & (branch_type_B[0] == 1'b1) ? 1'b1: //p
                             (nzp_B == 3'b100) & (branch_type_B[2] == 1'b1) ? 1'b1: //n
                              1'b0; 

   // Register input calcuted here and then passed through writeback
   wire [15:0] rd_data_A, rd_data_B;
   assign rd_data_A = EX_is_load_A ? i_cur_dmem_data :
                      EX_select_pc_plus_one_A ? pc_plus_two_A :
                      alu_result_A;
   assign rd_data_B = EX_is_load_B ? i_cur_dmem_data :
                      EX_select_pc_plus_one_B ? pc_plus_two_B :
                      alu_result_B;

   // Next pc calculated here
   assign next_pc = (EX_is_branch_A & is_true_branch_A) | EX_is_control_insn_A ? alu_result_A : pc_plus_two_A; // next_pc based on which insns come out of decode

   // ============================================== MEMORY Stage ===============================================
   // ************************************* [Execute to] Memory Register ****************************************
   wire [15:0] MEM_insn_A, MEM_alu_result_A, MEM_pc_A, MEM_rs_data_A, MEM_rt_data_A, MEM_rd_data_A, MEM_next_pc, MEM_dmem_data,
               MEM_insn_B, MEM_alu_result_B, MEM_pc_B, MEM_rs_data_B, MEM_rt_data_B, MEM_rd_data_B;
   wire [2:0] MEM_nzp_new_bits_A, MEM_nzp_new_bits_B;
   wire MEM_is_load_A, MEM_is_store_A, MEM_nzp_we_A, MEM_is_load_B, MEM_is_store_B, MEM_nzp_we_B;

   Nbit_reg #(16) EXMEM_insn_A(.out(MEM_insn_A), .in(EX_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_pc_A(.out(MEM_pc_A), .in(EX_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_alu_result_A(.out(MEM_alu_result_A), .in(alu_result_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_rs_data_A(.out(MEM_rs_data_A), .in(EX_rs_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_rt_data_A(.out(MEM_rt_data_A), .in(EX_rt_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_rd_data_A(.out(MEM_rd_data_A), .in(rd_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_insn_B(.out(MEM_insn_B), .in(EX_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_pc_B(.out(MEM_pc_B), .in(EX_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_alu_result_B(.out(MEM_alu_result_B), .in(alu_result_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_rs_data_B(.out(MEM_rs_data_B), .in(EX_rs_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_rt_data_B(.out(MEM_rt_data_B), .in(EX_rt_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_rd_data_B(.out(MEM_rd_data_B), .in(rd_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16) EXMEM_next_pc(.out(MEM_next_pc), .in(next_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) EXMEM_dmem_data(.out(MEM_dmem_data), .in(i_cur_dmem_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(3) EXMEM_nzp_new_bits_A(.out(MEM_nzp_new_bits_A), .in(nzp_in_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3) EXMEM_nzp_new_bits_B(.out(MEM_nzp_new_bits_B), .in(nzp_in_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(1) EXMEM_is_load_A(.out(MEM_is_load_A), .in(EX_is_load_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) EXMEM_is_store_A(.out(MEM_is_store_A), .in(EX_is_store_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) EXMEM_nzp_we_A(.out(MEM_nzp_we_A), .in(EX_nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) EXMEM_is_load_B(.out(MEM_is_load_B), .in(EX_is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) EXMEM_is_store_B(.out(MEM_is_store_B), .in(EX_is_store_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) EXMEM_nzp_we_B(.out(MEM_nzp_we_B), .in(EX_nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   // ****************************************** END Memory Register ********************************************

   wire [15:0] MEM_dmem_addr_A, MEM_dmem_towrite_A, MEM_dmem_data_A, MEM_dmem_addr_B, MEM_dmem_towrite_B, MEM_dmem_data_B;
   wire MEM_dmem_we_A, MEM_dmem_we_B;
   
   // Data Memory (memory stage)
   assign MEM_dmem_addr_A = MEM_is_load_A ? MEM_alu_result_A :
                        MEM_is_store_A ? MEM_alu_result_A :
                        16'b0;
   assign MEM_dmem_towrite_A = MEM_rt_data_A;
   assign MEM_dmem_we_A = MEM_is_store_A;
   assign MEM_dmem_data_A = MEM_is_load_A ? MEM_dmem_data :
                          MEM_is_store_A ? MEM_dmem_towrite_A :
                          16'b0;

   assign MEM_dmem_addr_B = MEM_is_load_B ? MEM_alu_result_B :
                          MEM_is_store_B ? MEM_alu_result_B :
                          16'b0;
   assign MEM_dmem_towrite_B = MEM_rt_data_B;
   assign MEM_dmem_we_B = MEM_is_store_B;
   assign MEM_dmem_data_B = MEM_is_load_B ? MEM_dmem_data :
                            MEM_is_store_B ? MEM_dmem_towrite_B :
                            16'b0;

   // ================================================ Writeback Stage ======================================================
   // *************************************** [Memory to] Writeback Pipeline Register ***************************************
   wire [15:0] WB_pc_A, WB_insn_A, WB_rd_data_A, WB_dmem_addr_A, WB_dmem_data_A, WB_pc_B, WB_insn_B, WB_rd_data_B, WB_dmem_addr_B, WB_dmem_data_B;
   wire [15:0] WB_next_pc;
   wire [2:0] WB_nzp_new_bits_A, WB_nzp_new_bits_B;
   wire WB_regfile_we_A, WB_nzp_we_A, WB_dmem_we_A, WB_regfile_we_B, WB_nzp_we_B, WB_dmem_we_B;

   Nbit_reg #(16) MEMWB_pc_A(.out(WB_pc_A), .in(MEM_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) MEMWB_insn_A(.out(WB_insn_A), .in(MEM_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) MEMWB_rd_data_A(.out(WB_rd_data_A), .in(MEM_rd_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) MEMWB_dmem_addr_A(.out(WB_dmem_addr_A), .in(MEM_dmem_addr_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) MEMWB_dmem_data_A(.out(WB_dmem_data_A), .in(MEM_dmem_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(3) MEMWB_nzp_new_bits_A(.out(WB_nzp_new_bits_A), .in(MEM_nzp_new_bits_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(1) MEMWB_regfile_we_A(.out(WB_regfile_we_A), .in(MEM_dmem_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) MEMWB_nzp_we_A(.out(WB_nzp_we_A), .in(MEM_nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) MEMWB_dmem_we_A(.out(WB_dmem_we_A), .in(MEM_dmem_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16) MEMWB_pc_B(.out(WB_pc_B), .in(MEM_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) MEMWB_insn_B(.out(WB_insn_B), .in(MEM_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) MEMWB_rd_data_B(.out(WB_rd_data_B), .in(MEM_rd_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) MEMWB_dmem_addr_B(.out(WB_dmem_addr_B), .in(MEM_dmem_addr_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) MEMWB_dmem_data_B(.out(WB_dmem_data_B), .in(MEM_dmem_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(3) MEMWB_nzp_new_bits_B(.out(WB_nzp_new_bits_B), .in(MEM_nzp_new_bits_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(1) MEMWB_regfile_we_B(.out(WB_regfile_we_B), .in(MEM_dmem_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) MEMWB_nzp_we_B(.out(WB_nzp_we_B), .in(MEM_nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1) MEMWB_dmem_we_B(.out(WB_dmem_we_B), .in(MEM_dmem_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16) MEMWB_next_pc(.out(WB_next_pc), .in(MEM_next_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   // ******************************************** END Writeback Pipeline Register ******************************************

   // Assign the next pc and output current pc (writeback stage)                     
   assign o_cur_pc = WB_pc_A;

   assign test_cur_pc_A = WB_pc_A;
   assign test_cur_insn_A = WB_insn_A;
   assign test_regfile_data_A = WB_rd_data_A;
   assign test_dmem_addr_A = WB_dmem_addr_A;
   assign test_dmem_data_A = WB_dmem_data_A;
   
   assign test_nzp_new_bits_A = WB_nzp_new_bits_A;
   
   assign test_regfile_we_A = WB_regfile_we_A;
   assign test_nzp_we_A = WB_nzp_we_A;
   assign test_dmem_we_A = WB_dmem_we_A;

   assign test_cur_pc_B = WB_pc_B;
   assign test_cur_insn_B = WB_insn_B;
   assign test_regfile_data_B = WB_rd_data_B;
   assign test_dmem_addr_B = WB_dmem_addr_B;
   assign test_dmem_data_B = WB_dmem_data_B;
   
   assign test_nzp_new_bits_B = WB_nzp_new_bits_B;
   
   assign test_regfile_we_B = WB_regfile_we_B;
   assign test_nzp_we_B = WB_nzp_we_B;
   assign test_dmem_we_B = WB_dmem_we_B;

   assign test_stall_A = 0;
   assign test_stall_B = 0;


                        // output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                        // output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)
   
                        // output wire [15:0] test_cur_pc_A,       // program counter
                        // output wire [15:0] test_cur_pc_B,
                        // output wire [15:0] test_cur_insn_A,     // instruction bits
                        // output wire [15:0] test_cur_insn_B,
                        // output wire        test_regfile_we_A,   // register file write-enable
                        // output wire        test_regfile_we_B,
                        // output wire [ 2:0] test_regfile_wsel_A, // which register to write
                        // output wire [ 2:0] test_regfile_wsel_B,
                        // output wire [15:0] test_regfile_data_A, // data to write to register file
                        // output wire [15:0] test_regfile_data_B,
                        // output wire        test_nzp_we_A,       // nzp register write enable
                        // output wire        test_nzp_we_B,
                        // output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                        // output wire [ 2:0] test_nzp_new_bits_B,
                        // output wire        test_dmem_we_A,      // data memory write enable
                        // output wire        test_dmem_we_B,
                        // output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                        // output wire [15:0] test_dmem_addr_B,
                        // output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                        // output wire [15:0] test_dmem_data_B,
                     
                              
                        // // Assign test wires
                        // assign test_cur_pc = pc;
                        // assign test_cur_insn = i_cur_insn;
                        // assign test_regfile_we = regfile_we;
                        // assign test_regfile_wsel = wsel;
                        // assign test_regfile_data = rd_data;
                        // assign test_nzp_we = nzp_we;
                        // assign test_nzp_new_bits = nzp_in;
                        // assign test_dmem_we = o_dmem_we;
                        // assign test_dmem_addr = o_dmem_addr;
                        // assign test_dmem_data = is_load ? i_cur_dmem_data :
                        //                         is_store ? o_dmem_towrite :
                        //                         16'b0;

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nanoseconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display();
   end
endmodule
