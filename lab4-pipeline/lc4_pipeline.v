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

    // pc wires attached to the PC register's ports
    wire[15:0] pc;               // Currrent program counter read out from pc_reg
    wire[15:0] next_pc;          // Next program counter (computed and fed into next_pc)

    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // Instantiate fetch to decode register
   wire [31:0] input_fd, output_fd;
   wire [15:0] pc_inc, insn_from_fd, pc_from_fd;
   cla16 c0(.a(pc), .b(16'b0), .cin(1'b1), .sum(pc_inc));

   assign input_fd = {pc_inc, i_cur_insn};
   Nbit_reg# (32) fetch_to_decode (.in(input_fd), .out(output_fd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign pc_from_fd = output_fd[31:16];
   assign insn_from_fd = output_fd[15:0];
   
   wire[1:0] stall_fd, stall_de, stall_em, stall_mw, stall_w;
   assign stall_fd = 2'b10;
   Nbit_reg #(2, 2'b10) fetch_stall_reg (.in(stall_fd), .out(stall_de), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
   // Instantiate Decoder w input insn coming from fetch_to_decode
   wire [2:0] r1sel, r2sel, wsel;
   wire r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;
   lc4_decoder decoder (.insn(insn_from_fd),
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
   
   // Instantiate register file using decoded wires coming from decoder that took insn from fetch_to_decode
   wire [15:0] rs_data_to_de, rt_data_to_de, rd_data;
   lc4_regfile register (.clk(clk),
         .gwe(gwe),
         .rst(rst),
         .i_rs(r1sel),
         .o_rs_data(rs_data_to_de),
         .i_rt(r2sel),
         .o_rt_data(rt_data_to_de),
         .i_rd(wsel),
         .i_wdata(rd_data),
         .i_rd_we(regfile_we));

   // Instantiate decode to execute register
   wire [63:0] input_de, output_de;
   wire [15:0] pc_from_de, rs_data_from_de, rt_data_from_de, insn_from_de;
   assign input_de = {pc_from_fd, rs_data_to_de, rt_data_to_de, insn_from_fd};
   Nbit_reg #(64) decode_to_execute (.in(input_de), 
         .out(output_de), 
         .clk(clk),
         .we(1'b1), 
         .gwe(gwe), 
         .rst(rst));
  
   Nbit_reg #(2, 2'b10) decode_stall(.in(stall_de), .out(stall_em), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   // Instantiate ALU
   assign insn_from_de = output_de[15:0];
   assign pc_from_de = output_de[63:48];
   assign rs_data_from_de = output_de[47:32];
   assign rt_data_from_de = output_de[31:16];
   wire [15:0] alu_result;
   lc4_alu alu (.i_insn(insn_from_de),
       .i_pc(pc_from_de),
       .i_r1data(rs_data_from_de), 
       .i_r2data(rt_data_from_de), 
       .o_result(alu_result));

   // Execute to memory register
   wire[64:0] input_em, output_em;
   assign input_em = {pc_from_de, 1'b0, alu_result, rt_data_from_de, insn_from_de};
   Nbit_reg #(65) execute_to_memory (.in(input_em), .out(output_em), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   assign stall_em = (insn_from_de == 16'h0000) ? 2 : 0;
   Nbit_reg #(2, 2'b10) execute_stall (.in(stall_em), .out(stall_mw), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   wire [15:0] pc_from_em, alu_result_from_em, rt_data_from_em, insn_from_em;
   assign pc_from_em = output_em[64:49];
   wire zero = output_em[48];
   assign alu_result_from_em = output_em[47:32];
   assign rt_data_from_em = output_em[31:16];
   assign insn_from_em = output_em[15:0];
   
   // Data memory TODO: propogate control signals through registers
   assign o_dmem_addr = is_load ? alu_result :
         is_store ? alu_result :
         16'b0;
   assign o_dmem_towrite = rt_data_from_em;
   assign o_dmem_we = is_store;

   // Memory to writeback register
   wire[47:0] input_mw, output_mw;
   assign input_mw = {i_cur_dmem_data, alu_result_from_em, insn_from_em};
   Nbit_reg #(48) memory_to_writeback (.in(input_mw), .out(output_mw), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10) memory_stall (.in(stall_mw), .out(stall_w), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   wire[15:0] insn_from_mw, alu_result_from_mw;

   // Reg input mux
   assign rd_data = is_load ? i_cur_dmem_data : 
          select_pc_plus_one == 1'b1 ? pc_inc :
          alu_result_from_mw;


   // branching
   assign next_pc = (is_branch) | is_control_insn ? alu_result_from_mw : pc_inc;
   assign o_cur_pc = pc_from_em;

   // assign test wires
   assign test_stall = 0;
   assign test_cur_pc = pc_from_em;
   assign test_cur_insn = i_cur_insn;
   assign test_regfile_we = regfile_we;
   assign test_regfile_wsel = wsel;
   assign test_regfile_data = rd_data;
   assign test_nzp_we = 1;
   assign test_nzp_new_bits = 3'b100;
   assign test_dmem_we = o_dmem_we;
   assign test_dmem_addr = o_dmem_addr;
   assign test_dmem_data = is_load ? i_cur_dmem_data :
                           is_store ? o_dmem_towrite :
                           16'b0;
   

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
