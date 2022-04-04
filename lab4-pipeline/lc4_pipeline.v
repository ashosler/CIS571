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
    wire [1:0] dec_stall, ex_stall, mem_stall, wb_stall;


   // ======================== DECODE Stage ==============================
   // Decode stall register
    Nbit_reg #(2, 2'b10) FD_StallReg (.out(dec_stall), .in(wb_stall), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst)); // TODO: what should be done about 

   // Wires for fetch to decode register
    wire [15:0] DEC_pc_inc, DEC_insn, pc_inc, DEC_pc;
    wire fd_we;

    // Increment pc to pass through registers
    cla16 c0(.a(pc),
	    .b(16'b0),
	    .cin(1'b1),
	    .sum(pc_inc));

    // Register(s) for fetch to decode
    Nbit_reg #(16) FD_PCInc(.in(pc_inc), .out(DEC_pc_inc), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst)); //TODO: write enable determined based on the result of stall
    Nbit_reg #(16, 16'b0) FD_Insn(.out(DEC_insn), .in(i_cur_insn), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) FD_Pc(.out(DEC_pc), .in(pc), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst));

    // Wires for decoder
    wire [2:0] r1sel, r2sel, wsel, WB_wsel; // 3 3-bit select wires
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
    wire [15:0] rs_data, rt_data, rd_data;

    // Instantiate register file
    lc4_regfile RegisterFile (.clk(clk),
		   .gwe(gwe),
		   .rst(rst),
		   .i_rs(r1sel),
		   .o_rs_data(rs_data),
		   .i_rt(r2sel),
		   .o_rt_data(rt_data),
		   .i_rd(WB_wsel),
		   .i_wdata(rd_data),
		   .i_rd_we(regfile_we));

    // Use WD bypass when the instruction in writeback stage writes to register that insn in Decode stage wants to read from
    wire use_wd_bypass_rs = ((regfile_we == 1) && (WB_wsel == r1sel) && (DEC_insn != 16'b0)); // assuming nop is 16'b0
    wire use_wd_bypass_rt = ((regfile_we == 1) && (WB_wsel == r2sel) && (DEC_insn != 16'b0));

    /* You either read the value from the register file, or the value that's
       currently being written to the register file (from the W stage). */
    wire [15:0] wd_bypass_rsdata = use_wd_bypass_rs ? rd_data : rs_data;
    wire [15:0] wd_bypass_rtdata = use_wd_bypass_rt ? rd_data : rt_data;

    // ========================= EXECUTE Stage ===========================
    // Wires for decode to execute pipeline register
    wire [15:0] EX_pc_inc, EX_rs_data, EX_rt_data, EX_insn, EX_pc; // May not need EX_insn (resolved: need to pass insn through wb for test wires)
    wire [2:0] EX_r1sel, EX_r2sel, EX_wsel; // Should we still pass through r1 and r2 sel? (resolved: yes for stall logic)
    wire [8:0] EX_ctrls; // control signals concatenated into one wire and output as this
    wire EX_r1re, EX_r2re, EX_regfile_we, EX_nzp_we, EX_select_pc_plus_one,
     EX_is_load, EX_is_store, EX_is_branch, EX_is_control_insn;

    // Pipeline register(s) for decode to execute
    Nbit_reg #(16) DE_PCInc (.out(EX_pc_inc), .in(DEC_pc_inc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) DE_RSData (.out(EX_rs_data), .in(wd_bypass_rsdata), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); // use wd_bypass_output mux result here instead of rs_data?
    Nbit_reg #(16) DE_RTData (.out(EX_rt_data), .in(wd_bypass_rtdata), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) DE_Pc (.out(EX_pc), .in(DEC_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // Pipeline register for decoded register write select
    Nbit_reg #(3) DE_WSel (.out(EX_wsel), .in(wsel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); // Not sure which wsel to put in here
    Nbit_reg #(3) DE_R1Sel (.out(EX_r1sel), .in(r1sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) DE_R2Sel (.out(EX_r2sel), .in(r2sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // Pipeline registers for decoded insn controls from decode to execute
    Nbit_reg #(9) DE_CTRL_Signals (.out(EX_ctrls), 
      .in({r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn}),
      .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    assign EX_r1re = EX_ctrls[8];
    assign EX_r2re = EX_ctrls[7];
    assign EX_regfile_we = EX_ctrls[6];
    assign EX_nzp_we = EX_ctrls[5];
    assign EX_select_pc_plus_one = EX_ctrls[4];
    assign EX_is_load = EX_ctrls[3];
    assign EX_is_store = EX_ctrls[2];
    assign EX_is_branch = EX_ctrls[1];
    assign EX_is_control_insn = EX_ctrls[0];

    // Stall logic for input into stall register
    wire is_stall = (((EX_r1sel == EX_wsel) & EX_r1re) |((EX_r2sel == EX_wsel) & EX_r2re & (!EX_is_load))) & EX_is_load;
    wire [1:0] ex_stall_input = is_stall ? 2'b11 :
         DEC_insn == 16'b0 ? 2'b10 : 2'b0;

    assign pc_we = (ex_stall_input != 0) ? 1'b1 : 1'b0;
    assign fd_we = (ex_stall_input != 0) ? 1'b1 : 1'b0;

    // Stall register for [decode to] execute
    Nbit_reg #(2, 2'b10) DE_Stall (.out(ex_stall), .in(ex_stall_input), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst));

    /* Choose to pass along a nop – 16'b0 – or the previous insn to DE pipeline reg based on the result of stall */
    wire [15:0] DE_input_insn = (ex_stall_input == 2'b11) ? 16'b0 : DEC_insn;
    Nbit_reg #(16, 16'b0) DE_Insn (.out(EX_insn), .in(DE_input_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // TODO: Not sure where but need to add functionality for sign extend and shift left
    
    // Instantiate ALU (TODO: ALU needs muxes as input)
    wire [15:0] alu_result;
    lc4_alu ALU (.i_insn(EX_insn), .i_pc(EX_pc), 
         .i_r1data(EX_rs_data), .i_r2data(EX_rt_data), .o_result(alu_result));

    // NZP register**
    wire [2:0] nzp, nzp_new_bits;
    wire [15:0] sel_nzp;
    assign sel_nzp = EX_is_load ? i_cur_dmem_data :
            EX_insn[15:12] == 4'b1111 ? EX_pc_inc :
            alu_result;
    assign nzp_new_bits = sel_nzp == 16'b0 ? 3'b010 :
            sel_nzp[15] == 1'b0 ? 3'b001 : 
            3'b100;
    Nbit_reg #(3) NZP_Reg (.out(nzp), .in(nzp_new_bits), .clk(clk), .we(EX_nzp_we), .gwe(gwe), .rst(rst));

    // =============================== MEMORY Stage =====================================
    // Stall register for [execute to] memory
    Nbit_reg #(2, 2'b10) EM_Stall (.out(mem_stall), .in(ex_stall), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst));

    // Wires for [execute to] memory pipeline register(s)
    wire [15:0] MEM_pc_inc, MEM_alu_result, MEM_rt_data, MEM_insn, MEM_pc;
    wire [2:0] MEM_wsel, MEM_nzp;
    wire [8:0] MEM_ctrls;
    wire MEM_r1re, MEM_r2re, MEM_regfile_we, MEM_nzp_we, MEM_select_pc_plus_one,
     MEM_is_load, MEM_is_store, MEM_is_branch, MEM_is_control_insn;

    // Pipeline registers [execute to] memory
    Nbit_reg #(16) EM_PCinc (.out(MEM_pc_inc), .in(EX_pc_inc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) EM_ALUResult (.out(MEM_alu_result), .in(alu_result), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) EM_RTData (.out(MEM_rt_data), .in(EX_rt_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b0) EM_Insn (.out(MEM_insn), .in(EX_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) EM_Pc (.out(MEM_pc), .in(EX_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) EM_Wsel (.out(MEM_wsel), .in(EX_wsel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) EM_nzp (.out(MEM_nzp), .in(nzp), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    // Pipeline registers for decoded insn controls from execute to memory
    Nbit_reg #(9) EM_CTRL_Signals (.out(MEM_ctrls), 
     .in({EX_r1re, EX_r2re, EX_regfile_we, EX_nzp_we, EX_select_pc_plus_one, EX_is_load, EX_is_store, EX_is_branch, EX_is_control_insn}),
     .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

     assign MEM_r1re = MEM_ctrls[8];
     assign MEM_r2re = MEM_ctrls[7];
     assign MEM_regfile_we = MEM_ctrls[6];
     assign MEM_nzp_we = MEM_ctrls[5];
     assign MEM_select_pc_plus_one = MEM_ctrls[4];
     assign MEM_is_load = MEM_ctrls[3];
     assign MEM_is_store = MEM_ctrls[2];
     assign MEM_is_branch = MEM_ctrls[1];
     assign MEM_is_control_insn = MEM_ctrls[0]; 
     
    // Data memory logic (didn't make any change to logic from single cycle/Do we have to?)
    assign o_dmem_addr = MEM_is_load ? MEM_alu_result :
         MEM_is_store ? MEM_alu_result :
         16'b0;
    assign o_dmem_towrite = MEM_rt_data;
    assign o_dmem_we = MEM_is_store;

    // Branch unit
    wire is_true_branch;
    wire [2:0] branch_type = MEM_insn[11:9];
    assign is_true_branch = (MEM_nzp == 3'b010) & (branch_type[1] == 1'b1) ? 1'b1 :
               (nzp == 3'b001) & (branch_type[0] == 1'b1) ? 1'b1 :
               (nzp == 3'b100) & (branch_type[2] == 1'b1) ? 1'b1 :
               1'b0;
    assign next_pc = (MEM_is_branch & is_true_branch) | MEM_is_control_insn ? MEM_alu_result : MEM_pc_inc;

    // ================================ WRITEBACK Stage ==================================
    // Stall register for [memory to] writeback
    Nbit_reg #(2, 2'b10) MW_Stall(.out(wb_stall), .in(mem_stall), .clk(clk), .we(fd_we), .gwe(gwe), .rst(rst));

    // Wires for [memory to] writeback pipeline register
    wire [15:0] WB_pc_inc, WB_alu_result, WB_dmem_data, WB_dmem_addr, WB_dmem_towrite, WB_insn, WB_pc;
    wire WB_dmem_we;
    wire [2:0] WB_nzp;
    wire [8:0] WB_ctrls;
    
    wire WB_r1re, WB_r2re, WB_regfile_we, WB_nzp_we, WB_select_pc_plus_one,
     WB_is_load, WB_is_store, WB_is_branch, WB_is_control_insn;

    // Register(s) for [memory to] writeback pipeline
    Nbit_reg #(16) MW_PCInc (.out(WB_pc_inc), .in(MEM_pc_inc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) MW_ALUResult (.out(WB_alu_result), .in(MEM_alu_result), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) MW_DMEMData (.out(WB_dmem_data), .in(i_cur_dmem_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) MW_DMEMAddr (.out(WB_dmem_addr), .in(o_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) MW_DMEMToWrite (.out(WB_dmem_towrite), .in(o_dmem_towrite), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) MW_Insn (.out(WB_insn), .in(MEM_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    Nbit_reg #(16) MW_Pc (.out(WB_pc), .in(MEM_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    Nbit_reg #(3) MW_WSel (.out(WB_wsel), .in(MEM_wsel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) MW_nzp (.out(WB_nzp), .in(MEM_nzp), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) MW_DMemWE (.out(WB_dmem_we), .in(o_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // Pipeline registers for decoded insn controls from memory to writeback
    Nbit_reg #(9) MW_CTRL_Signals (.out(WB_ctrls), 
     .in({MEM_r1re, MEM_r2re, MEM_regfile_we, MEM_nzp_we, MEM_select_pc_plus_one, MEM_is_load, MEM_is_store, MEM_is_branch, MEM_is_control_insn}),
     .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

     assign WB_r1re = WB_ctrls[8];
     assign WB_r2re = WB_ctrls[7];
     assign WB_regfile_we = WB_ctrls[6];
     assign WB_nzp_we = WB_ctrls[5];
     assign WB_select_pc_plus_one = WB_ctrls[4];
     assign WB_is_load = WB_ctrls[3];
     assign WB_is_store = WB_ctrls[2];
     assign WB_is_branch = WB_ctrls[1];
     assign WB_is_control_insn = WB_ctrls[0];

    // Mux to control register input
    assign rd_data = WB_is_load == 1'b1 ? WB_dmem_data : 
         select_pc_plus_one == 1'b1 ? WB_pc_inc :
         WB_alu_result;
     
    // Assign test signals
    assign test_cur_pc = WB_pc; // The current pc needs to be passed all the way through WB pipeline
    assign test_cur_insn = WB_insn;
    assign test_regfile_we = WB_regfile_we;
    assign test_regfile_wsel = WB_wsel;
    assign test_regfile_data = rd_data;
    assign test_nzp_we = WB_nzp_we;
    assign test_nzp_new_bits = WB_nzp;
    assign test_dmem_we = WB_dmem_we;
    assign test_dmem_addr = WB_dmem_addr;
    assign test_dmem_data = WB_is_load ? WB_dmem_data :
         WB_is_store ? WB_dmem_towrite :
         16'b0;
    assign test_stall = 2'b0;

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
