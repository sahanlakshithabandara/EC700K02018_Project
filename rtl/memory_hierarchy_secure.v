/******************************************************************************
* Module: memory_hierarchy.v
* Integrates a cache hierarchy consisting of two L1 caches, shared L2 cache,
* main memory and a coherence controller.
******************************************************************************/

module memory_hierarchy #(
parameter STATUS_BITS_L1        = 2,
          STATUS_BITS_L2        = 3,
          COHERENCE_BITS        = 2,
          OFFSET_BITS           = 2,
          DATA_WIDTH            = 32,
          NUMBER_OF_WAYS_L1     = 2,
          NUMBER_OF_WAYS_L2     = 4,
          REPLACEMENT_MODE_BITS = 1,
	      ADDRESS_WIDTH         = 32,
	      INDEX_BITS_L1         = 5,
	      INDEX_BITS_L2         = 6,
		  INDEX_BITS_MEMORY     = 10,
	      MSG_BITS              = 3,
          NUM_L1_CACHES         = 2,
		  NUM_MEMORY_PORTS      = 2,
		  INIT_FILE             = "./instructions.dat"
)
(
clock, reset,
read0, read1, write0, write1, invalidate0, invalidate1, flush0, flush1,
address0, address1,
data_in0, data_in1,
replacement_mode,
report_l1_0, report_l1_1, report_l2, report,
data_out0, data_out1,
out_address0, out_address1,
ready0, ready1, valid0, valid1,

interface2mem_msg,
interface2mem_address,
interface2mem_data,
mem2interface_msg,
mem2interface_address,
mem2interface_data,

lxb2mm_msg,
lxb2mm_address,
lxb2mm_data,
mm2lxb_msg,
mm2lxb_address,
mm2lxb_data,

secure_op
);

//localparams
localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam BUS_WIDTH_L1   = STATUS_BITS_L1 + COHERENCE_BITS + DATA_WIDTH*WORDS_PER_LINE;
localparam BUS_WIDTH_L2   = STATUS_BITS_L2 + COHERENCE_BITS + DATA_WIDTH*WORDS_PER_LINE;

`include "./params.v"

// wires and registers
input clock, reset;
input read0, read1, write0, write1, invalidate0, invalidate1, flush0, flush1;
input [ADDRESS_WIDTH-1 : 0] address0, address1;
input [DATA_WIDTH-1 : 0] data_in0, data_in1;
input replacement_mode;
input report_l1_0, report_l1_1, report_l2, report;

output [DATA_WIDTH-1 : 0] data_out0, data_out1;
output [ADDRESS_WIDTH-1 : 0] out_address0, out_address1;
output ready0, ready1, valid0,valid1;

output wire [MSG_BITS-1 : 0] interface2mem_msg;
output wire [ADDRESS_WIDTH-1 : 0] interface2mem_address;
output wire [DATA_WIDTH-1 : 0] interface2mem_data;

input [MSG_BITS-1 : 0] mem2interface_msg;
input [ADDRESS_WIDTH-1 : 0] mem2interface_address;
input [DATA_WIDTH-1 : 0] mem2interface_data;

output wire      [MSG_BITS-1:0] lxb2mm_msg;
output wire [ADDRESS_WIDTH-1:0] lxb2mm_address;
output wire    [DATA_WIDTH-1:0] lxb2mm_data;
input            [MSG_BITS-1:0] mm2lxb_msg;
input       [ADDRESS_WIDTH-1:0] mm2lxb_address;
input          [DATA_WIDTH-1:0] mm2lxb_data;

input                           secure_op;

wire [BUS_WIDTH_L1-1 : 0] cache2mem_data0, cache2mem_data1;
wire [ADDRESS_WIDTH-1 : 0] cache2mem_address0, cache2mem_address1;
wire [MSG_BITS-1 : 0] cache2mem_msg0, cache2mem_msg1;
wire [BUS_WIDTH_L1-1 : 0] mem2cache_data0, mem2cache_data1;
wire [ADDRESS_WIDTH-1 : 0] mem2cache_address0, mem2cache_address1;
wire [MSG_BITS-1 : 0] mem2cache_msg0, mem2cache_msg1;
wire [MSG_BITS-1 : 0] coherence_msg_in0, coherence_msg_in1, coherence_msg_out0,
                      coherence_msg_out1;
wire [BUS_WIDTH_L1-1 : 0] coherence_data0, coherence_data1;
wire [ADDRESS_WIDTH-1 : 0] coherence_address0, coherence_address1;
wire [NUM_L1_CACHES*BUS_WIDTH_L1-1 : 0] cache2cc_data, cc2mem_data,
                                     cache2cc_coh_data, Lx2cache_data;
wire [NUM_L1_CACHES*ADDRESS_WIDTH-1 : 0] cache2cc_address, cc2mem_address,
                                      Lx2cache_address;
wire [NUM_L1_CACHES*MSG_BITS-1 : 0] cache2cc_msg, cc2mem_msg, cc2cache_msg,
                               cache2cc_coh_msg, cc2cache_coh_msg, Lx2cache_msg;
wire [BUS_WIDTH_L2-1 : 0] cache2interface_data;
wire [ADDRESS_WIDTH-1 : 0] cache2interface_address, cc2cache_coh_address;
wire [MSG_BITS-1 : 0] cache2interface_msg;

///
wire [MSG_BITS-1 : 0] interface2cache_msg;
wire [ADDRESS_WIDTH-1 : 0] interface2cache_address;
wire [BUS_WIDTH_L2-1 : 0] interface2cache_data;

wire [MSG_BITS-1 : 0] network2cache_msg;
wire [ADDRESS_WIDTH-1 : 0] network2cache_address;
wire [DATA_WIDTH-1 : 0] network2cache_data;

wire [MSG_BITS-1 : 0] cache2network_msg;
wire [ADDRESS_WIDTH-1 : 0] cache2network_address;
wire [DATA_WIDTH-1 : 0] cache2network_data;

wire      [MSG_BITS-1:0] bypass2cache_msg0;
wire [ADDRESS_WIDTH-1:0] bypass2cache_address0;
wire  [BUS_WIDTH_L1-1:0] bypass2cache_data0;
wire      [MSG_BITS-1:0] cache2bypass_msg0;
wire [ADDRESS_WIDTH-1:0] cache2bypass_address0;
wire  [BUS_WIDTH_L1-1:0] cache2bypass_data0;

wire      [MSG_BITS-1:0] bypass2cache_msg1;
wire [ADDRESS_WIDTH-1:0] bypass2cache_address1;
wire  [BUS_WIDTH_L1-1:0] bypass2cache_data1;
wire      [MSG_BITS-1:0] cache2bypass_msg1;
wire [ADDRESS_WIDTH-1:0] cache2bypass_address1;
wire  [BUS_WIDTH_L1-1:0] cache2bypass_data1;

///

assign cache2cc_data      = {cache2mem_data1, cache2mem_data0};
assign cache2cc_address   = {cache2mem_address1, cache2mem_address0};
assign cache2cc_msg       = {cache2mem_msg1, cache2mem_msg0};
assign cache2cc_coh_msg   = {coherence_msg_out1, coherence_msg_out0};
assign cache2cc_coh_data  = {coherence_data1, coherence_data0};
assign coherence_msg_in0  = cc2cache_coh_msg[0*MSG_BITS +: MSG_BITS];
assign coherence_msg_in1  = cc2cache_coh_msg[1*MSG_BITS +: MSG_BITS];
assign coherence_address0 = cc2cache_coh_address;
assign coherence_address1 = cc2cache_coh_address;
assign mem2cache_address0 = Lx2cache_address[0*ADDRESS_WIDTH +: ADDRESS_WIDTH];
assign mem2cache_address1 = Lx2cache_address[1*ADDRESS_WIDTH +: ADDRESS_WIDTH];
assign mem2cache_data0    = Lx2cache_data[0*BUS_WIDTH_L1 +: BUS_WIDTH_L1];
assign mem2cache_data1    = Lx2cache_data[1*BUS_WIDTH_L1 +: BUS_WIDTH_L1];
assign mem2cache_msg0     = Lx2cache_msg[0*MSG_BITS +: MSG_BITS];
assign mem2cache_msg1     = Lx2cache_msg[1*MSG_BITS +: MSG_BITS];

assign network2cache_msg = 0;
assign network2cache_address = 0;
assign network2cache_data = 0;

//instantiate modules
//L1 cache 0
L1cache #(.STATUS_BITS           (STATUS_BITS_L1),
          .COHERENCE_BITS        (COHERENCE_BITS),
          .OFFSET_BITS           (OFFSET_BITS),
          .DATA_WIDTH            (DATA_WIDTH),
          .NUMBER_OF_WAYS        (NUMBER_OF_WAYS_L1),
          .REPLACEMENT_MODE_BITS (REPLACEMENT_MODE_BITS),
          .ADDRESS_WIDTH         (ADDRESS_WIDTH),
          .INDEX_BITS            (INDEX_BITS_L1),
          .MSG_BITS              (MSG_BITS),
          .CORE                  (32'd0), 
          .CACHE_NO              (32'd0)
          )
  L1_0 (.clock                (clock),
        .reset                (reset),
        .read                 (read0),
        .write                (write0),
        .invalidate           (invalidate0),
        .flush                (flush0),
        .replacement_mode     (replacement_mode),
        .address              (address0),
        .data_in              (data_in0),
        .report               (report_l1_0|report),
        .data_out             (data_out0),
        .out_address          (out_address0),
        .ready                (ready0), 
        .valid                (valid0), 
        .mem2cache_msg        (mem2cache_msg0),
        .mem2cache_data       (mem2cache_data0),
        .mem2cache_address    (mem2cache_address0),
        .cache2mem_msg        (cache2mem_msg0),
        .cache2mem_data       (cache2mem_data0), 
        .cache2mem_address    (cache2mem_address0),

        .secure_op            (secure_op),
        .cache2bypass_msg     (cache2bypass_msg0),
        .cache2bypass_address (cache2bypass_address0),
        .cache2bypass_data    (cache2bypass_data0),
        .bypass2cache_msg     (bypass2cache_msg0),
        .bypass2cache_address (bypass2cache_address0),
        .bypass2cache_data    (bypass2cache_data0),

        .coherence_msg_in     (coherence_msg_in0),
        .coherence_address    (coherence_address0),
        .coherence_msg_out    (coherence_msg_out0),
        .coherence_data       (coherence_data0)
        );
		  
//L1 cache 1
L1cache #(.STATUS_BITS           (STATUS_BITS_L1),
          .COHERENCE_BITS        (COHERENCE_BITS),
          .OFFSET_BITS           (OFFSET_BITS),
          .DATA_WIDTH            (DATA_WIDTH),
          .NUMBER_OF_WAYS        (NUMBER_OF_WAYS_L1),
          .REPLACEMENT_MODE_BITS (REPLACEMENT_MODE_BITS),
          .ADDRESS_WIDTH         (ADDRESS_WIDTH),
          .INDEX_BITS            (INDEX_BITS_L1),
          .MSG_BITS              (MSG_BITS),
          .CORE                  (32'd1),
          .CACHE_NO              (32'd1)
          )
  L1_1 (.clock                (clock),
        .reset                (reset),
        .read                 (read1),
        .write                (write1),
        .invalidate           (invalidate1),
        .flush                (flush1),
        .replacement_mode     (replacement_mode),
        .address              (address1),
        .data_in              (data_in1),
        .report               (report_l1_1|report),
        .data_out             (data_out1),
        .out_address          (out_address1),
        .ready                (ready1),
        .valid                (valid1),
        .mem2cache_msg        (mem2cache_msg1),
        .mem2cache_data       (mem2cache_data1),
        .mem2cache_address    (mem2cache_address1),
        .cache2mem_msg        (cache2mem_msg1),
        .cache2mem_data       (cache2mem_data1), 
        .cache2mem_address    (cache2mem_address1),

        .secure_op            (secure_op),
        .bypass2cache_msg     (bypass2cache_msg1),
        .bypass2cache_data    (bypass2cache_data1),
        .bypass2cache_address (bypass2cache_address1),
        .cache2bypass_msg     (cache2bypass_msg1),
        .cache2bypass_data    (cache2bypass_data1),
        .cache2bypass_address (cache2bypass_address1),

        .coherence_msg_in     (coherence_msg_in1),
        .coherence_address    (coherence_address1),
        .coherence_msg_out    (coherence_msg_out1),
        .coherence_data       (coherence_data1)
        );
		  
//Coherence controller
coherence_controller #(STATUS_BITS_L1, COHERENCE_BITS, INDEX_BITS_L1, OFFSET_BITS, DATA_WIDTH, ADDRESS_WIDTH,
                       MSG_BITS, NUM_L1_CACHES)
                       C_CTRL (clock, reset, cache2cc_data, cache2cc_address, cache2cc_msg,
                       cc2mem_data, cc2mem_address, cc2mem_msg, Lx2cache_msg, cache2cc_coh_msg,
                       cache2cc_coh_data, cc2cache_coh_msg, cc2cache_coh_address);
					   
//L2 cache
Lxcache #(STATUS_BITS_L2, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH, NUMBER_OF_WAYS_L2,
          REPLACEMENT_MODE_BITS, ADDRESS_WIDTH, INDEX_BITS_L2, MSG_BITS, NUM_L1_CACHES, 2)
          L2_0 (clock, reset, cc2mem_address, cc2mem_data, cc2mem_msg, (report_l2|report),
                Lx2cache_data, Lx2cache_address, Lx2cache_msg, interface2cache_msg,
                interface2cache_address, interface2cache_data, cache2interface_msg,
                cache2interface_address, cache2interface_data);

// L2 bypass
assign {bypass2cache_data1[131:128], bypass2cache_data0[131:128]} = 8'h99;

Lxbypass #(.ABW(ADDRESS_WIDTH), .NUM_ULC(NUM_L1_CACHES)) u_Lxbypass (
  // Clocks and resets
  .reset          (reset), // (I) Asynchronous reset, active high
  .clock          (clock), // (I) Clock

  // L1 Cache Interface
  .msg_in         ({cache2bypass_msg1,         cache2bypass_msg0}),         // (I)
  .address        ({cache2bypass_address1,     cache2bypass_address0}),     // (I)
  .data_in        ({cache2bypass_data1[127:0], cache2bypass_data0[127:0]}), // (I)

  .msg_out        ({bypass2cache_msg1,         bypass2cache_msg0}),         // (O)
  .out_address    ({bypass2cache_address1,     bypass2cache_address0}),     // (O)
  .data_out       ({bypass2cache_data1[127:0], bypass2cache_data0[127:0]}), // (O)

  // Main Memory Interface
  .mm2lxb_msg     (mm2lxb_msg),     // (I)
  .mm2lxb_address (mm2lxb_address), // (I)
  .mm2lxb_data    (mm2lxb_data),    // (I)

  .lxb2mm_msg     (lxb2mm_msg),     // (O)
  .lxb2mm_address (lxb2mm_address), // (O)
  .lxb2mm_data    (lxb2mm_data)     // (O)
);
				
//Main memory interface
main_memory_interface #( STATUS_BITS_L2, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH,
    ADDRESS_WIDTH, MSG_BITS)
    DUT_intf(clock, reset, cache2interface_msg, cache2interface_address,
        cache2interface_data, interface2cache_msg, interface2cache_address,
        interface2cache_data, network2cache_msg, network2cache_address,
        network2cache_data, cache2network_msg, cache2network_address, 
        cache2network_data, mem2interface_msg, mem2interface_address,
        mem2interface_data, interface2mem_msg, interface2mem_address,
        interface2mem_data);
			
endmodule
