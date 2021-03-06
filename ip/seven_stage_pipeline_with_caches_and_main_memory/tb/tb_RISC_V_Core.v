/** @module : tb_RISC_V_Core
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.

 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 *
 */

 module tb_RISC_V_Core(); 

parameter INDEX_BITS = 6;
parameter OFFSET_BITS = 3;
parameter ADDRESS_BITS = 12;
parameter LOG_FILE = "mandelbrot_instructions_dcache.log";
parameter PROGRAM  = "../short_mandelbrot.mem";
 
reg clock, reset, start; 
reg [19:0] prog_address; 
reg report; // performance reporting

// For I/O funstions
reg [1:0]    from_peripheral;
reg [31:0]   from_peripheral_data;
reg          from_peripheral_valid;

wire [1:0]  to_peripheral;
wire [31:0] to_peripheral_data;
wire        to_peripheral_valid;

integer log_file;

RISC_V_Core #(
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .PROGRAM(PROGRAM)
  ) CORE (
    .clock(clock), 
    .reset(reset), 
    .start(start), 
    .prog_address(prog_address[11:0]),	
    .from_peripheral(from_peripheral),
    .from_peripheral_data(from_peripheral_data),
    .from_peripheral_valid(from_peripheral_valid),
    .to_peripheral(to_peripheral),
    .to_peripheral_data(to_peripheral_data),
    .to_peripheral_valid(to_peripheral_valid),
          
    .isp_address(12'd0),
    .isp_data(0),
    .isp_write(1'b0),
    .report(report),
    .current_PC()
); 

    // Clock generator
    always #1 clock = ~clock;

    initial begin
          log_file = $fopen(LOG_FILE, "w+");
          if(!log_file) begin
            $display("Could not open log file... Exiting!");
            $finish();
          end

          clock  = 0;
          reset  = 1;
          report = 0; 
          prog_address = 'h0;
          repeat (2) @ (posedge clock);
          
          #1reset = 0;
          start = 1; 
          repeat (1) @ (posedge clock);
          
          start = 0; 
          repeat (1) @ (posedge clock);        
     end


// print cache read addresses and data out.
reg [ADDRESS_BITS-1 : 0] addr0, addr1;
reg req0, req1;

always @(negedge clock)begin
  if(reset)begin
    req0 = 0;
    req1 = 0;
  end
  else begin
    if(CORE.IF.i_mem_read)begin 
        //$display("PC_reg: %h | REQ_address: %h | ", CORE.IF.PC_reg, CORE.IF.i_mem_read_address);
        case({req1, req0})
            2'b00:begin
                req1  = 1;
                addr1 = CORE.IF.PC_reg;
            end
            2'b10:begin
                req0  = 1;
                addr0 = CORE.IF.PC_reg;
            end
            2'b01:begin
                req1  = 1;
                req0  = 1;
                addr0 = CORE.IF.PC_reg;
                addr1 = addr0;
            end
            2'b11:begin
                $display("ERROR! Cache is not ready to accept a request.-> addr1:%h | addr0:%h | PC_reg:%h ###############################################", addr1, addr0, CORE.IF.PC_reg);
                addr1 = addr0;
                addr0 = CORE.IF.PC_reg;
            end
        endcase
    end
    if(CORE.IF.i_mem_valid)begin
        //$display("out_address: %h | inst_PC: %h | instruction: %h", 
        //    CORE.IF.i_mem_out_addr, 
        //    CORE.IF.inst_PC, 
        //    CORE.IF.instruction);
        if(req1 & (addr1 == CORE.IF.inst_PC))
            if(req0)begin
                req0  = 0;
                addr1 = addr0;
            end
            else
                req1 = 0;
        else
            $display("ERROR!!! Returning data for wrong address. addr1:%h | addr0:%h | inst_PC:%h #############################", addr1, addr0, CORE.IF.inst_PC);
    end
  end
end

// instruction at execute stage
always @(negedge clock)begin
  if(~(CORE.regWrite_execute==1'b0 & CORE.memWrite_execute==1'b0 & CORE.branch_op_execute==1'b0
  & CORE.next_PC_select_execute==2'b00 & CORE.rd_execute==5'b00000) & 
  ~(CORE.regWrite_execute==1'b1 & CORE.memWrite_execute==1'b0 & CORE.branch_op_execute==1'b0
  & CORE.next_PC_select_execute==2'b00 & CORE.rd_execute==5'b00000))begin
    $display("Decode_pipe PC:%h | instruction:%h | regWrite:%b | memWrite:%b | branch_op:%b | PC_select:%b | RD:%d", 
        CORE.PC_execute, CORE.instruction_execute, CORE.regWrite_execute, CORE.memWrite_execute, 
        CORE.branch_op_execute, CORE.next_PC_select_execute, CORE.rd_execute);
    $fdisplay(log_file, "Decode_pipe PC:%h | instruction:%h | regWrite:%b | memWrite:%b | branch_op:%b | PC_select:%b | RD:%d", 
        CORE.PC_execute, CORE.instruction_execute, CORE.regWrite_execute, CORE.memWrite_execute, 
        CORE.branch_op_execute, CORE.next_PC_select_execute, CORE.rd_execute);

    if(CORE.instruction_execute == 32'h06f75263)begin
      $display("BGE => rs1:%h | rs2:%h", CORE.rs1_data_execute, CORE.rs2_data_execute);
      $fdisplay(log_file, "BGE => rs1:%h | rs2:%h", CORE.rs1_data_execute, CORE.rs2_data_execute);
    end
  end
end

// memory writes
/*always @(negedge clock)begin
    if(CORE.EU_MU.memWrite_memory1)begin
        $display("PC_memory1:%h | instruction:%h | write_addr:%h | write_data:%h",
            CORE.EU_MU.PC_memory1,
            CORE.EU_MU.instruction_memory1, CORE.EU_MU.ALU_result_memory1,
            CORE.EU_MU.store_data_memory1);

        $fdisplay(log_file, "PC_memory1:%h | instruction:%h | write_addr:%h | write_data:%h",
            CORE.EU_MU.PC_memory1,
            CORE.EU_MU.instruction_memory1, CORE.EU_MU.ALU_result_memory1,
            CORE.EU_MU.store_data_memory1);
    end
end*/

//memory reads
/*always @(negedge clock)begin
    if(CORE.EU_MU.memRead_memory1)begin
        $display("PC_memory1:%h | instruction:%h | read_addr:%h",
            CORE.EU_MU.PC_memory1, CORE.EU_MU.instruction_memory1,
            CORE.EU_MU.ALU_result_memory1);
        $fdisplay(log_file, "PC_memory1:%h | instruction:%h | read_addr:%h",
            CORE.EU_MU.PC_memory1, CORE.EU_MU.instruction_memory1,
            CORE.EU_MU.ALU_result_memory1);
    end
end*/

/*always @(negedge clock)begin
    if(CORE.MU_WB.load_data_valid)begin
        $display("load_data_addr:%h | load_data:%h",
            CORE.MU_WB.load_data_addr, CORE.MU_WB.load_data_memory2);
        $fdisplay(log_file, "load_data_addr:%h | load_data:%h",
            CORE.MU_WB.load_data_addr, CORE.MU_WB.load_data_memory2);
    end
end*/

//write back
/*always @(negedge clock)begin
    if(CORE.MU_WB.opwrite_writeback & CORE.MU_WB.opSel_writeback &
    ~CORE.MU_WB.stall_wb)begin
        $display("PC_wb:%h | instruction_wb:%h | RD:%h | data_wb:%h | data_addr:%h",
            CORE.MU_WB.PC_writeback, CORE.MU_WB.instruction_writeback,
            CORE.MU_WB.opReg_writeback, CORE.MU_WB.load_data_writeback,
            CORE.MU_WB.wb_data_addr);
        $fdisplay(log_file, "PC_wb:%h | instruction_wb:%h | RD:%h | data_wb:%h | data_addr:%h",
            CORE.MU_WB.PC_writeback, CORE.MU_WB.instruction_writeback,
            CORE.MU_WB.opReg_writeback, CORE.MU_WB.load_data_writeback,
            CORE.MU_WB.wb_data_addr);
    end
end*/

// ----------------------------------------------------------------------------
// Counters for performance:
//
reg   [31:0] clock_cycles;

always @(posedge clock) begin
  if (reset) begin
    clock_cycles <= 32'd0;
  end else begin
    clock_cycles <= clock_cycles+1;
  end
end

// ----------------------------------------------------------------------------
// End-of-Simulation Snooping:
//
always @(negedge clock) begin
  if (CORE.PC_memory1[11:0] == 12'h0B0) begin
    $display("Test Completed after %0d clock cycles", clock_cycles);
    $display("The result is %0d", tb_RISC_V_Core.CORE.ID.registers.register_file[9]);
    $finish;
  end
end

endmodule
