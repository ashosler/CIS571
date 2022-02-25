/* Names: Allison Hosler and Antaures Jackson
 * Pennkeys: ashosler and ajj4311
 *
 * lc4_single.v
 * Implements a single-cycle data path
 *
 */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // Main clock
    input  wire        rst,                // Global reset
    input  wire        gwe,                // Global we for single-step clock
   
    output wire [15:0] o_cur_pc,           // Address to read from instruction memory
    input  wire [15:0] i_cur_insn,         // Output of instruction memory
    output wire [15:0] o_dmem_addr,        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
    input  wire [15:0] i_cur_dmem_data,    // Output of data memory
    output wire        o_dmem_we,          // Data memory write enable
    output wire [15:0] o_dmem_towrite,     // Value to write to data memory

    // Testbench signals are used by the testbench to verify the correctness of your datapath.
    // Many of these signals simply export internal processor state for verification (such as the PC).
    // Some signals are duplicate output signals for clarity of purpose.
    //
    // Don't forget to include these in your schematic!

    output wire [1:0]  test_stall,         // Testbench: is this a stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc,        // Testbench: program counter
    output wire [15:0] test_cur_insn,      // Testbench: instruction bits
    output wire        test_regfile_we,    // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel,  // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data,  // Testbench: value to write into the register file
    output wire        test_nzp_we,        // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits,  // Testbench: value to write to NZP bits
    output wire        test_dmem_we,       // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr,     // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data,     // Testbench: value read/writen from/to memory
   
    input  wire [7:0]  switch_data,        // Current settings of the Zedboard switches
    output wire [7:0]  led_data            // Which Zedboard LEDs should be turned on?
    );

   // By default, assign LEDs to display switch inputs to avoid warnings about
   // disconnected ports. Feel free to use this for debugging input/output if
   // you desire.
   assign led_data = switch_data;

   
   /* DO NOT MODIFY THIS CODE */
   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   assign test_stall = 2'b0; 

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   /* END DO NOT MODIFY THIS CODE */


   /*******************************
    * TODO: START YOUR CODE HERE *
    *******************************/

   // Instantiate Decoder
   wire [2:0] 	 r1sel, r2sel, wsel;
   wire 	 r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;
   lc4_decoder d0 (.insn(i_cur_insn),
		   .r1sel(r1sel),
		   .r1re(r1re),
		   .r2sel(r2sel),
		   .r2re(r2re),
		   .wsel(wsel),
		   .regfile_we(regfile_we),
		   .nzp_we(nzp_we),
		   .select_pc_plus_one(select_pc_plus_one),
		   .is_load(is_load),
		   .is_store(is_store),
		   .is_branch(is_branch),
		   .is_control_insn(is_control_insn));

   // Register Data Wires
   wire [15:0] 	 rs_data, rt_data, rd_data, alu_result;
      
   // Instantiate Register File
   lc4_regfile f0 (.clk(clk),
		   .gwe(gwe),
		   .rst(rst),
		   .i_rs(r1sel),
		   .o_rs_data(rs_data),
		   .i_rt(r2sel),
		   .o_rt_data(rt_data),
		   .i_rd(wsel),
		   .i_wdata(rd_data),
		   .i_rd_we(regfile_we));
   
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
			      
   
   
   /*******************************   
    * TODO: END YOUR CODE HERE *
    *******************************/


   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    * 
    * To disable the entire block add the statement
    * `define NDEBUG
    * to the top of your file.  We also define this symbol
    * when we run the grading scripts.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
       //$display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      
      $display("PC: %d", pc);
      $display("insn: %b %h", i_cur_insn, i_cur_insn);
      $display("ALU: %b", alu_result);
      $display("sel_nzp: %b   nzp_in: %b", sel_nzp, nzp_in);
      if (regfile_we) begin
          $display("WRITE to R%d: %b", wsel, rd_data);
          end
      if (o_dmem_we) begin
          $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);
	  end

      if (o_cur_pc != pc_inc) begin
          $display("JUMP to PC: %d", o_cur_pc);
          end
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
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecial.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

       $display();
   end
`endif
endmodule
