/*  Names: Alison Hosler and Antaures Jackson
    Pennkeys: ashosler and ajj4311
*/

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this is stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter
    output wire [15:0] test_cur_insn, // Testbench: instruction bits
    output wire        test_regfile_we, // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );
   
    assign led_data = switch_data;

    /* Note on wire nomenclature: Wires that come from register will have that registers tag (FET, DEC, EXE, MEM, WRI)
       at the beginning. For example the pc wire coming from the FD register will be named FD_pc. */
    
    // ======================== Fetch Stage ==============================
    // pc wires attached to the PC register's ports
    wire[15:0] pc;               // Currrent program counter read out from pc_reg
    wire[15:0] next_pc;          // Next program counter (computed and fed into next_pc)
    wire pc_we;

    
    // Program counter register should start at 8200 at bootup
    Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(pc_we), .gwe(gwe), .rst(rst));

    // Stall wires and flush wires
    wire [1:0] fd_stall, de_stall, em_stall, mw_stall;
    wire fet_flush, fd_flush; // Not sure if we need more


   // ======================== DECODE Stage ==============================
   // Wires for fetch to decode register
    wire [15:0] DEC_pc_inc, DEC_insn, pc_inc;
    wire fd_we;

    // Increment pc to pass through registers
    cla16 c0(.a(pc),
	    .b(16'b0),
	    .cin(1'b1),
	    .sum(pc_inc));

    // Register(s) for fetch to decode
    Nbit_reg #(16) FD_PCINC(.out(DEC_pc_inc), .in(pc_inc), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) FD_INSN(.out(DEC_insn), .in(i_cur_insn), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) (.out(fd_stall), .in(mw_stall), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst)); // NOT SURE if mw_stall should be input here
    Nbit_reg #(1) (.out(fd_flush), .in(fet_flush), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst));

    // Wires for decoder
    wire [2:0] r1sel, r2sel, wsel; // 3 3-bit select wires
    wire  r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;  // 9 single bit control wires

    // Instantiate decoder
    lc4_decoder Decoder (.insn(DEC_insn),
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

    // Register data wires
    wire [15:0] rs_data, rt_data, rd_data, alu_result;

    // Instantiate register file
    lc4_regfile RegisterFile (.clk(clk),
		   .gwe(gwe),
		   .rst(rst),
		   .i_rs(r1sel),
		   .o_rs_data(rs_data),
		   .i_rt(r2sel),
		   .o_rt_data(rt_data),
		   .i_rd(wsel),
		   .i_wdata(rd_data),
		   .i_rd_we(regfile_we));

    // ========================= EXECUTE Stage ===========================
    // Register(s) for decode to execute
    Nbit_reg #(16) 
 
    /* You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      //$display("PC: %d", pc);

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
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display(); 
   end
`endif
endmodule
