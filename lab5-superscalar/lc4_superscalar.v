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
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // =================================== DECODE Stage ===============================================
   // *************** [Fetch to] Decode Register ********************
   wire [15:0] DEC_insn_A, DEC_insn_B;

   Nbit_reg #(16) IFID_insn_A(.out(DEC_insn_A), .in(i_cur_insn_A), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16) IFID_insn_B(.out(DEC_insn_B), .in(i_cur_insn_B), .we(1'b1), .gwe(gwe), .rst(rst));

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
      
   // Instantiate Register File
   lc4_regfile_ss Register_ss (.clk(clk), .gwe(gwe), .rst(rst),
                  .i_rs_A(r1sel_A), .o_rs_data_A(rs_data_A), .i_rt_A(r2sel_A), .o_rt_data_A(rt_data_A),
                  .i_rs_B(r2sel_B), .o_rs_data_B(rs_data_B), .i_rt_B(r2sel_B), .o_rt_data_B(rt_data_B),
                  .i_rd_A(wsel_A), .i_wdata_A(/* TODO */), .i_rd_we_A(regfile_we_A),
                  .i_rd_B(wsel_B), .i_wdata_B(/* TODO */), .i_rd_we_B(regfile_we_B));
                        
   // Instantiate ALU                                            
   lc4_alu a0 (.i_insn(i_cur_insn),
               .i_pc(pc),
               .i_r1data(rs_data),
               .i_r2data(rt_data),
               .o_result(alu_result));
                        
                        // Data Memory
                        assign o_dmem_addr = is_load ? alu_result :
                              is_store ? alu_result :
                              16'b0;
                        assign o_dmem_towrite = rt_data;
                        assign o_dmem_we = is_store;
                     
                        // regInputMux 
                        wire 	 [15:0] pc_inc;
                        cla16 c0(.a(pc),
                            .b(16'b0),
                            .cin(1'b1),
                            .sum(pc_inc));
                        assign rd_data = is_load == 1'b1 ? i_cur_dmem_data :
                               select_pc_plus_one == 1'b1 ? pc_inc :
                               alu_result; 
                     
                        // NZP Register (CMPs nzp_we)
                        wire [2:0] 		nzp, nzp_in;
                        wire [15:0] 		sel_nzp;
                        assign sel_nzp = is_load ? i_cur_dmem_data :
                               i_cur_insn[15:12] == 4'b1111 ? pc_inc : //TRAP (or should it be all control insn?)
                               alu_result;
                        assign nzp_in = sel_nzp == 16'b0 ? 3'b010 :
                              //sel_nzp > 16'b0 ? 3'b001 :
                              sel_nzp[15] == 1'b0 ? 3'b001 :
                              3'b100;
                        Nbit_reg #(3) nzp_reg (.in(nzp_in), .out(nzp), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));
                        
                        // Branch Unit
                        wire	is_true_branch;
                        wire [2:0] branch_type = i_cur_insn[11:9];
                        assign is_true_branch = (nzp == 3'b010) & (branch_type[1] == 1'b1) ? 1'b1: //z
                                 (nzp == 3'b001) & (branch_type[0] == 1'b1) ? 1'b1: //p
                                 (nzp == 3'b100) & (branch_type[2] == 1'b1) ? 1'b1: //n
                                 1'b0;
                        assign next_pc = (is_branch & is_true_branch) | is_control_insn ? alu_result : pc_inc;
                        assign o_cur_pc = pc;
                              
                        // Assign test wires
                        assign test_cur_pc = pc;
                        assign test_cur_insn = i_cur_insn;
                        assign test_regfile_we = regfile_we;
                        assign test_regfile_wsel = wsel;
                        assign test_regfile_data = rd_data;
                        assign test_nzp_we = nzp_we;
                        assign test_nzp_new_bits = nzp_in;
                        assign test_dmem_we = o_dmem_we;
                        assign test_dmem_addr = o_dmem_addr;
                        assign test_dmem_data = is_load ? i_cur_dmem_data :
                                                is_store ? o_dmem_towrite :
                                                16'b0;

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
