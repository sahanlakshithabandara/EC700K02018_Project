/** @module : fetch_pipe_unit
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
 */
//////////////////////////////////////////////////////////////////////////////////


module fetch_pipe_unit #(parameter  DATA_WIDTH = 32, ADDRESS_BITS = 20 ) (
    input clock, reset, stall, 
    input  [DATA_WIDTH-1:0]   instruction_fetch,
    input  [ADDRESS_BITS-1:0] inst_PC_fetch,
    input  valid_fetch,
    input  JAL_detected,
    
    output [DATA_WIDTH-1:0]   instruction_decode,
    output [ADDRESS_BITS-1:0] inst_PC_decode,
    output valid_decode
);

localparam NOP = 32'h00000013;

reg old_stall;
reg [DATA_WIDTH-1:0]   old_instruction_decode;
reg [ADDRESS_BITS-1:0] inst_PC_fetch_to_decode;
reg valid_fetch_to_decode;
reg [DATA_WIDTH-1:0] instruction_fetch_to_decode;

assign inst_PC_decode      =  inst_PC_fetch;
assign valid_decode        =  valid_fetch;
assign instruction_decode  =  instruction_fetch;

always @(posedge clock) begin
    if(reset) begin
        inst_PC_fetch_to_decode     <= {ADDRESS_BITS{1'b0}};
        old_instruction_decode      <= NOP;
        old_stall                   <= 1'b0;
        valid_fetch_to_decode       <= 1'b0;
        instruction_fetch_to_decode <= NOP;
    end
    else begin
        inst_PC_fetch_to_decode     <= inst_PC_fetch;
        old_instruction_decode      <= instruction_decode;
        old_stall                   <= stall;
        valid_fetch_to_decode       <= (JAL_detected)? 1'b0 :valid_fetch;
        instruction_fetch_to_decode <= (valid_fetch)? instruction_fetch: NOP;
    end
end

endmodule
