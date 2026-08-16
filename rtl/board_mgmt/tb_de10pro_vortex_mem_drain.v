`timescale 1ns/1ps

module tb_de10pro_vortex_mem_drain;

    localparam QUIET_CYCLES = 4;

    reg clk;
    reg reset;
    reg drain_req_async;
    wire drain_ack;
    wire [9:0] outstanding_read_beats;

    reg [32:0] s0_address;
    reg [4:0] s0_burstcount;
    reg [511:0] s0_writedata;
    reg [63:0] s0_byteenable;
    reg s0_read;
    reg s0_write;
    reg s0_debugaccess;
    wire s0_waitrequest;
    wire [511:0] s0_readdata;
    wire s0_readdatavalid;

    wire [32:0] m0_address;
    wire [4:0] m0_burstcount;
    wire [511:0] m0_writedata;
    wire [63:0] m0_byteenable;
    wire m0_read;
    wire m0_write;
    wire m0_debugaccess;
    reg m0_waitrequest;
    reg [511:0] m0_readdata;
    reg m0_readdatavalid;

    integer wait_cycles;

    de10pro_vortex_mem_drain #(
        .OUTSTANDING_WIDTH (10),
        .QUIET_CYCLES      (QUIET_CYCLES)
    ) dut (
        .clk                    (clk),
        .reset                  (reset),
        .drain_req_async        (drain_req_async),
        .drain_ack              (drain_ack),
        .outstanding_read_beats (outstanding_read_beats),
        .s0_address             (s0_address),
        .s0_burstcount          (s0_burstcount),
        .s0_writedata           (s0_writedata),
        .s0_byteenable          (s0_byteenable),
        .s0_read                (s0_read),
        .s0_write               (s0_write),
        .s0_debugaccess         (s0_debugaccess),
        .s0_waitrequest         (s0_waitrequest),
        .s0_readdata            (s0_readdata),
        .s0_readdatavalid       (s0_readdatavalid),
        .m0_address             (m0_address),
        .m0_burstcount          (m0_burstcount),
        .m0_writedata           (m0_writedata),
        .m0_byteenable          (m0_byteenable),
        .m0_read                (m0_read),
        .m0_write               (m0_write),
        .m0_debugaccess         (m0_debugaccess),
        .m0_waitrequest         (m0_waitrequest),
        .m0_readdata            (m0_readdata),
        .m0_readdatavalid       (m0_readdatavalid)
    );

    always begin
        #5 clk = ~clk;
    end

    task check_transparent;
        begin
            #1;
            if ((m0_address !== s0_address)
             || (m0_burstcount !== s0_burstcount)
             || (m0_writedata !== s0_writedata)
             || (m0_byteenable !== s0_byteenable)
             || (m0_read !== s0_read)
             || (m0_write !== s0_write)
             || (m0_debugaccess !== s0_debugaccess)
             || (s0_waitrequest !== m0_waitrequest)
             || (s0_readdata !== m0_readdata)
             || (s0_readdatavalid !== m0_readdatavalid)) begin
                $fatal(1, "Avalon pass-through changed a signal");
            end
        end
    endtask

    task wait_for_request_sync;
        input expected_value;
        begin
            wait_cycles = 0;
            while ((dut.drain_req_sync !== expected_value) && (wait_cycles < 20)) begin
                @(posedge clk);
                #1;
                wait_cycles = wait_cycles + 1;
            end
            if (dut.drain_req_sync !== expected_value) begin
                $fatal(1, "drain request synchronizer timeout");
            end
        end
    endtask

    task require_no_ack;
        input integer cycle_count;
        integer index;
        begin
            for (index = 0; index < cycle_count; index = index + 1) begin
                @(posedge clk);
                #1;
                if (drain_ack) begin
                    $fatal(1, "drain_ack asserted before the interface drained");
                end
            end
        end
    endtask

    task require_ack_after_quiet;
        begin
            require_no_ack(QUIET_CYCLES - 1);
            @(posedge clk);
            #1;
            if (!drain_ack) begin
                $fatal(1, "drain_ack did not assert after the quiet window");
            end
        end
    endtask

    task send_read_beat;
        input [511:0] data_value;
        begin
            @(negedge clk);
            m0_readdata = data_value;
            m0_readdatavalid = 1'b1;
            check_transparent();
            @(posedge clk);
            #1;
            @(negedge clk);
            m0_readdatavalid = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        drain_req_async = 1'b0;
        s0_address = 33'b0;
        s0_burstcount = 5'd1;
        s0_writedata = 512'b0;
        s0_byteenable = 64'b0;
        s0_read = 1'b0;
        s0_write = 1'b0;
        s0_debugaccess = 1'b0;
        m0_waitrequest = 1'b0;
        m0_readdata = 512'b0;
        m0_readdatavalid = 1'b0;

        repeat (4) begin
            @(posedge clk);
        end
        @(negedge clk);
        reset = 1'b0;

        s0_address = 33'h123456780;
        s0_burstcount = 5'd7;
        s0_writedata = {16{32'h89abcdef}};
        s0_byteenable = 64'h55aa55aa55aa55aa;
        s0_read = 1'b1;
        s0_debugaccess = 1'b1;
        m0_waitrequest = 1'b1;
        m0_readdata = {16{32'h13579bdf}};
        m0_readdatavalid = 1'b1;
        check_transparent();
        @(negedge clk);
        s0_read = 1'b0;
        s0_debugaccess = 1'b0;
        m0_waitrequest = 1'b0;
        m0_readdatavalid = 1'b0;

        #2 drain_req_async = 1'b1;
        wait_for_request_sync(1'b1);
        require_no_ack(2);

        @(negedge clk);
        s0_write = 1'b1;
        m0_waitrequest = 1'b1;
        check_transparent();
        require_no_ack(QUIET_CYCLES + 2);

        @(negedge clk);
        m0_waitrequest = 1'b0;
        @(posedge clk);
        #1;
        if (drain_ack) begin
            $fatal(1, "accepted write did not clear the quiet window");
        end
        @(negedge clk);
        s0_write = 1'b0;
        require_ack_after_quiet();

        @(negedge clk);
        s0_write = 1'b1;
        m0_waitrequest = 1'b1;
        #1;
        if (drain_ack || !m0_write || !s0_waitrequest) begin
            $fatal(1, "new stalled write was gated or left drain_ack asserted");
        end
        require_no_ack(2);
        @(negedge clk);
        s0_write = 1'b0;
        m0_waitrequest = 1'b0;
        require_ack_after_quiet();

        @(negedge clk);
        #2 drain_req_async = 1'b0;
        wait_for_request_sync(1'b0);
        #1;
        if (drain_ack) begin
            $fatal(1, "drain_ack did not clear with drain_req");
        end

        @(negedge clk);
        s0_burstcount = 5'd3;
        s0_read = 1'b1;
        m0_waitrequest = 1'b0;
        @(posedge clk);
        #1;
        if (outstanding_read_beats !== 10'd3) begin
            $fatal(1, "accepted burst was not counted: %0d", outstanding_read_beats);
        end
        @(negedge clk);
        s0_read = 1'b0;
        #2 drain_req_async = 1'b1;
        wait_for_request_sync(1'b1);
        require_no_ack(QUIET_CYCLES + 2);

        send_read_beat({16{32'h11111111}});
        if ((outstanding_read_beats !== 10'd2) || drain_ack) begin
            $fatal(1, "first read response accounting failed");
        end
        send_read_beat({16{32'h22222222}});
        if ((outstanding_read_beats !== 10'd1) || drain_ack) begin
            $fatal(1, "second read response accounting failed");
        end
        send_read_beat({16{32'h33333333}});
        if ((outstanding_read_beats !== 10'd0) || drain_ack) begin
            $fatal(1, "last read response accounting failed");
        end
        require_ack_after_quiet();

        @(negedge clk);
        #2 drain_req_async = 1'b0;
        wait_for_request_sync(1'b0);

        @(negedge clk);
        s0_address = 33'h1abcdef00;
        s0_burstcount = 5'd1;
        s0_writedata = {16{32'hfedcba98}};
        s0_byteenable = 64'hffffffffffffffff;
        s0_write = 1'b1;
        m0_waitrequest = 1'b0;
        check_transparent();
        @(posedge clk);
        @(negedge clk);
        s0_write = 1'b0;
        if (drain_ack) begin
            $fatal(1, "drain_ack remained asserted after request release");
        end

        $display("PASS: de10pro_vortex_mem_drain");
        $finish;
    end

endmodule
