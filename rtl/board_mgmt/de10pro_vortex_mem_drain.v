`timescale 1ns/1ps

module de10pro_vortex_mem_drain #(
    parameter ADDRESS_WIDTH       = 33,
    parameter DATA_WIDTH          = 512,
    parameter BURSTCOUNT_WIDTH    = 5,
    parameter OUTSTANDING_WIDTH   = 16,
    parameter QUIET_CYCLES        = 8
) (
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         drain_req_async,
    output wire                         drain_ack,
    output reg  [OUTSTANDING_WIDTH-1:0] outstanding_read_beats,

    input  wire [ADDRESS_WIDTH-1:0]     s0_address,
    input  wire [BURSTCOUNT_WIDTH-1:0]  s0_burstcount,
    input  wire [DATA_WIDTH-1:0]        s0_writedata,
    input  wire [(DATA_WIDTH/8)-1:0]    s0_byteenable,
    input  wire                         s0_read,
    input  wire                         s0_write,
    input  wire                         s0_debugaccess,
    output wire                         s0_waitrequest,
    output wire [DATA_WIDTH-1:0]        s0_readdata,
    output wire                         s0_readdatavalid,

    output wire [ADDRESS_WIDTH-1:0]     m0_address,
    output wire [BURSTCOUNT_WIDTH-1:0]  m0_burstcount,
    output wire [DATA_WIDTH-1:0]        m0_writedata,
    output wire [(DATA_WIDTH/8)-1:0]    m0_byteenable,
    output wire                         m0_read,
    output wire                         m0_write,
    output wire                         m0_debugaccess,
    input  wire                         m0_waitrequest,
    input  wire [DATA_WIDTH-1:0]        m0_readdata,
    input  wire                         m0_readdatavalid
);

    localparam integer QUIET_COUNTER_WIDTH =
        (QUIET_CYCLES <= 1) ? 1 : $clog2(QUIET_CYCLES + 1);

    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg drain_req_meta;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg drain_req_sync;
    reg [QUIET_COUNTER_WIDTH-1:0] quiet_counter;
    reg drain_ack_reg;
    reg [OUTSTANDING_WIDTH:0] outstanding_math;
    reg [OUTSTANDING_WIDTH-1:0] outstanding_next;

    wire read_accepted;
    wire [BURSTCOUNT_WIDTH-1:0] accepted_read_beats;
    wire bus_activity;

    assign m0_address = s0_address;
    assign m0_burstcount = s0_burstcount;
    assign m0_writedata = s0_writedata;
    assign m0_byteenable = s0_byteenable;
    assign m0_read = s0_read;
    assign m0_write = s0_write;
    assign m0_debugaccess = s0_debugaccess;
    assign s0_waitrequest = m0_waitrequest;
    assign s0_readdata = m0_readdata;
    assign s0_readdatavalid = m0_readdatavalid;

    assign read_accepted = m0_read && !m0_waitrequest;
    assign accepted_read_beats = (s0_burstcount == 0)
                               ? {{(BURSTCOUNT_WIDTH-1){1'b0}}, 1'b1}
                               : s0_burstcount;
    assign bus_activity = m0_read || m0_write || m0_readdatavalid;
    assign drain_ack = drain_ack_reg
                     && drain_req_sync
                     && !bus_activity
                     && (outstanding_read_beats == 0);

    always @(*) begin
        outstanding_math = {1'b0, outstanding_read_beats};
        if (read_accepted) begin
            outstanding_math = outstanding_math + accepted_read_beats;
        end
        if (m0_readdatavalid && (outstanding_math != 0)) begin
            outstanding_math = outstanding_math - 1'b1;
        end
        outstanding_next = outstanding_math[OUTSTANDING_WIDTH-1:0];
    end

    always @(posedge clk) begin
        if (reset) begin
            drain_req_meta <= 1'b0;
            drain_req_sync <= 1'b0;
            outstanding_read_beats <= {OUTSTANDING_WIDTH{1'b0}};
        end else begin
            drain_req_meta <= drain_req_async;
            drain_req_sync <= drain_req_meta;
            outstanding_read_beats <= outstanding_next;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            quiet_counter <= {QUIET_COUNTER_WIDTH{1'b0}};
            drain_ack_reg <= 1'b0;
        end else if (!drain_req_sync) begin
            quiet_counter <= {QUIET_COUNTER_WIDTH{1'b0}};
            drain_ack_reg <= 1'b0;
        end else if (bus_activity || (outstanding_next != 0)) begin
            quiet_counter <= {QUIET_COUNTER_WIDTH{1'b0}};
            drain_ack_reg <= 1'b0;
        end else if (!drain_ack_reg) begin
            if ((QUIET_CYCLES <= 1)
             || (quiet_counter + 1'b1 >= QUIET_CYCLES)) begin
                drain_ack_reg <= 1'b1;
            end else begin
                quiet_counter <= quiet_counter + 1'b1;
            end
        end
    end

endmodule
