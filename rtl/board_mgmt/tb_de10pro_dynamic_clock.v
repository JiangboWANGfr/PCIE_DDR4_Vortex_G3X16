`timescale 1ns/1ps

module tb_de10pro_dynamic_clock;

    localparam integer QUIESCE_GUARD_CYCLES = 4;

    reg mgmt_clk;
    reg reset;
    reg apply;
    reg clear_status;
    reg [31:0] requested_hz;
    reg [31:0] request_sequence;
    wire busy;
    wire done;
    wire error;
    wire [31:0] error_code;
    wire [31:0] current_hz;
    wire current_valid;
    wire [31:0] done_sequence;
    wire [1:0] current_profile;
    wire [3:0] state;
    wire clock_change_req;
    wire clock_reset_req;
    reg clock_change_ack;
    reg memory_drain_ack;
    reg clock_reset_ack;
    reg pll_locked;
    reg vortex_clk;
    wire [31:0] measured_hz;
    wire [9:0] reconfig_address;
    wire reconfig_read;
    wire reconfig_write;
    wire [7:0] reconfig_writedata;
    reg [7:0] reconfig_readdata;
    reg reconfig_waitrequest;

    reg allow_quiesce;
    integer quiesce_delay;
    integer reconfig_delay;
    integer guard_cycle;
    integer guard_drop_count;
    reg [31:0] previous_vortex_gray;
    reg source_gray_valid;
    reg [31:0] source_gray_delta;

    de10pro_dynamic_clock #(
        .MGMT_CLK_HZ              (100),
        .MEASURE_WINDOW_CYCLES    (10),
        .QUIESCE_GUARD_CYCLES     (QUIESCE_GUARD_CYCLES),
        .QUIESCE_TIMEOUT_CYCLES   (30),
        .RECONFIG_TIMEOUT_CYCLES  (30),
        .LOCK_STABLE_CYCLES       (3)
    ) dut (
        .mgmt_clk            (mgmt_clk),
        .reset               (reset),
        .apply               (apply),
        .clear_status        (clear_status),
        .requested_hz        (requested_hz),
        .request_sequence    (request_sequence),
        .busy                (busy),
        .done                (done),
        .error               (error),
        .error_code          (error_code),
        .current_hz          (current_hz),
        .current_valid       (current_valid),
        .done_sequence       (done_sequence),
        .current_profile     (current_profile),
        .state               (state),
        .clock_change_req    (clock_change_req),
        .clock_reset_req     (clock_reset_req),
        .clock_change_ack    (clock_change_ack),
        .memory_drain_ack    (memory_drain_ack),
        .clock_reset_ack     (clock_reset_ack),
        .pll_locked          (pll_locked),
        .vortex_clk          (vortex_clk),
        .measured_hz         (measured_hz),
        .reconfig_address    (reconfig_address),
        .reconfig_read       (reconfig_read),
        .reconfig_write      (reconfig_write),
        .reconfig_writedata  (reconfig_writedata),
        .reconfig_readdata   (reconfig_readdata),
        .reconfig_waitrequest(reconfig_waitrequest)
    );

    always #5 mgmt_clk = ~mgmt_clk;
    always #2 vortex_clk = ~vortex_clk;

    always @(negedge vortex_clk) begin
        if (dut.vortex_reset_sync[1]) begin
            previous_vortex_gray = 32'b0;
            source_gray_valid = 1'b0;
            source_gray_delta = 32'b0;
        end else begin
            source_gray_delta = dut.vortex_counter_gray ^ previous_vortex_gray;
            if (source_gray_valid
             && ((source_gray_delta & (source_gray_delta - 1'b1)) != 0)) begin
                $fatal(1, "source-domain Gray counter changed more than one bit");
            end
            previous_vortex_gray = dut.vortex_counter_gray;
            source_gray_valid = 1'b1;
        end
    end

    always @(posedge mgmt_clk) begin
        if (reset) begin
            clock_change_ack <= 1'b0;
            clock_reset_ack <= 1'b0;
            quiesce_delay <= 0;
        end else begin
            if (!clock_change_req) begin
                clock_change_ack <= 1'b0;
                quiesce_delay <= 0;
            end else if (allow_quiesce && !clock_change_ack) begin
                if (quiesce_delay == 3) begin
                    clock_change_ack <= 1'b1;
                end else begin
                    quiesce_delay <= quiesce_delay + 1;
                end
            end
            clock_reset_ack <= clock_reset_req;
        end
    end

    always @(posedge mgmt_clk) begin
        if (reset) begin
            reconfig_waitrequest <= 1'b0;
            reconfig_delay <= 0;
        end else if (reconfig_write && !reconfig_waitrequest) begin
            reconfig_waitrequest <= 1'b1;
            reconfig_delay <= 5;
        end else if (reconfig_waitrequest) begin
            if (reconfig_delay == 0) begin
                reconfig_waitrequest <= 1'b0;
            end else begin
                reconfig_delay <= reconfig_delay - 1;
            end
        end else begin
            reconfig_waitrequest <= 1'b0;
        end
    end

    always @(posedge mgmt_clk) begin
        if (!reset && (state == 4'd5)
         && !dut.memory_drain_ack_sync[1]) begin
            $fatal(1, "clock FSM entered reconfiguration before memory drain");
        end
    end

    task issue_request;
        input [31:0] frequency_hz;
        input [31:0] sequence_value;
        begin
            @(negedge mgmt_clk);
            requested_hz = frequency_hz;
            request_sequence = sequence_value;
            apply = 1'b1;
            @(negedge mgmt_clk);
            apply = 1'b0;
        end
    endtask

    task wait_complete;
        integer wait_cycles;
        begin
            wait_cycles = 0;
            while ((!done || busy) && (wait_cycles < 300)) begin
                @(posedge mgmt_clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!done || busy) begin
                $fatal(1, "clock request did not complete: state=%0d", state);
            end
        end
    endtask

    initial begin
        mgmt_clk = 1'b0;
        reset = 1'b1;
        apply = 1'b0;
        clear_status = 1'b0;
        requested_hz = 32'b0;
        request_sequence = 32'b0;
        clock_change_ack = 1'b0;
        memory_drain_ack = 1'b0;
        clock_reset_ack = 1'b0;
        pll_locked = 1'b0;
        vortex_clk = 1'b0;
        reconfig_readdata = 8'b0;
        reconfig_waitrequest = 1'b0;
        allow_quiesce = 1'b1;
        quiesce_delay = 0;
        reconfig_delay = 0;
        guard_drop_count = 0;

        repeat (4) @(posedge mgmt_clk);
        reset = 1'b0;
        if (dut.vortex_reset_sync !== 2'b11) begin
            $fatal(1, "vortex reset deasserted asynchronously");
        end
        @(posedge vortex_clk);
        #1;
        if ((dut.vortex_reset_sync !== 2'b10)
         || (dut.vortex_counter !== 0) || (dut.vortex_counter_gray !== 0)) begin
            $fatal(1, "vortex reset did not hold through first release stage");
        end
        @(posedge vortex_clk);
        #1;
        if ((dut.vortex_reset_sync !== 2'b00)
         || (dut.vortex_counter !== 0) || (dut.vortex_counter_gray !== 0)) begin
            $fatal(1, "vortex reset did not hold through second release stage");
        end
        @(posedge vortex_clk);
        #1;
        if ((dut.vortex_counter !== 1) || (dut.vortex_counter_gray !== 1)) begin
            $fatal(1, "vortex counter did not start after synchronized release");
        end
        repeat (3) @(posedge mgmt_clk);
        pll_locked = 1'b1;
        while (busy) @(posedge mgmt_clk);
        if (!current_valid || (current_hz != 32'd200000000)) begin
            $fatal(1, "startup did not select 200 MHz");
        end
        repeat (20) @(posedge mgmt_clk);
        #1;
        if ((measured_hz < 32'd230) || (measured_hz > 32'd270)) begin
            $fatal(1, "registered Gray frequency measurement mismatch: %0d",
                measured_hz);
        end

        issue_request(32'd125000000, 32'h11);
        wait (clock_change_ack);
        repeat (5) @(posedge mgmt_clk);
        if (state != 4'd2 || clock_reset_req) begin
            $fatal(1, "shell-only quiesce ACK advanced the clock FSM");
        end
        memory_drain_ack = 1'b1;
        wait (state == 4'd6);
        repeat (4) begin
            @(posedge mgmt_clk);
            if ((state != 4'd6) || !clock_reset_req || current_valid) begin
                $fatal(1, "stale PLL lock released reset while reconfiguration was busy");
            end
        end
        pll_locked = 1'b0;
        repeat (4) @(posedge mgmt_clk);
        pll_locked = 1'b1;
        wait_complete();
        if (error || !current_valid || (current_hz != 32'd125000000)
         || (current_profile != 2'd1) || (done_sequence != 32'h11)) begin
            $fatal(1, "125 MHz request result mismatch");
        end

        @(negedge mgmt_clk);
        pll_locked = 1'b0;
        wait (!dut.pll_locked_sync[1]);
        @(negedge mgmt_clk);
        requested_hz = 32'd100000000;
        request_sequence = 32'h17;
        apply = 1'b1;
        @(negedge mgmt_clk);
        apply = 1'b0;
        if ((state != 4'd8) || busy || !done || !error
         || (error_code != 32'd5) || current_valid
         || !clock_change_req || !clock_reset_req
         || (current_hz != 32'd125000000)
         || (current_profile != 2'd1) || (done_sequence != 32'h17)) begin
            $fatal(1, "idle PLL lock-loss fail-safe mismatch");
        end

        pll_locked = 1'b1;
        wait (dut.pll_locked_sync[1]);
        issue_request(32'd125000000, 32'h18);
        wait_complete();
        if (error || !current_valid || (current_hz != 32'd125000000)
         || (current_profile != 2'd1) || (done_sequence != 32'h18)) begin
            $fatal(1, "PLL lock-loss recovery mismatch");
        end

        issue_request(32'd123000000, 32'h12);
        wait_complete();
        if (!error || (error_code != 32'd1)
         || (current_hz != 32'd125000000)) begin
            $fatal(1, "unsupported frequency was not rejected");
        end

        @(negedge mgmt_clk);
        clear_status = 1'b1;
        @(negedge mgmt_clk);
        clear_status = 1'b0;
        repeat (2) @(posedge mgmt_clk);
        if (done || error) begin
            $fatal(1, "clear status did not clear sticky bits");
        end

        allow_quiesce = 1'b1;
        memory_drain_ack = 1'b1;
        issue_request(32'd200000000, 32'h13);
        guard_drop_count = 0;
        while (!done && (guard_drop_count < 20)) begin
            wait ((state == 4'd3) || done);
            if (!done) begin
                @(negedge mgmt_clk);
                memory_drain_ack = 1'b0;
                wait ((state == 4'd2) || done);
                if (!done) begin
                    @(negedge mgmt_clk);
                    memory_drain_ack = 1'b1;
                    guard_drop_count = guard_drop_count + 1;
                end
            end
        end
        wait_complete();
        if (!error || (error_code != 32'd3) || clock_reset_req
         || (guard_drop_count < 2)) begin
            $fatal(1, "quiesce guard chatter escaped the shared timeout");
        end

        allow_quiesce = 1'b0;
        memory_drain_ack = 1'b1;
        issue_request(32'd200000000, 32'h14);
        wait_complete();
        if (!error || (error_code != 32'd3) || clock_reset_req) begin
            $fatal(1, "quiesce timeout handling mismatch");
        end

        allow_quiesce = 1'b1;
        memory_drain_ack = 1'b1;
        issue_request(32'd200000000, 32'h15);
        wait (state == 4'd6);
        pll_locked = 1'b0;
        wait_complete();
        if (!error || (state != 4'd8)) begin
            $fatal(1, "PLL timeout did not enter error hold");
        end

        memory_drain_ack = 1'b0;
        repeat (4) @(posedge mgmt_clk);
        if (!clock_change_ack) begin
            $fatal(1, "shell ACK was not held in error hold");
        end
        issue_request(32'd100000000, 32'h16);
        repeat (4) begin
            @(posedge mgmt_clk);
            #1;
            if ((state != 4'd2) || reconfig_write) begin
                $fatal(1, "retry bypassed quiesce without drain ACK");
            end
        end

        memory_drain_ack = 1'b1;
        wait (state == 4'd3);
        for (guard_cycle = 0;
             guard_cycle < QUIESCE_GUARD_CYCLES - 1;
             guard_cycle = guard_cycle + 1) begin
            @(posedge mgmt_clk);
            #1;
            if ((state != 4'd3) || reconfig_write) begin
                $fatal(1, "retry did not complete the drain guard");
            end
        end
        @(posedge mgmt_clk);
        #1;
        if ((state != 4'd4) || reconfig_write) begin
            $fatal(1, "retry left the drain guard at the wrong cycle");
        end
        @(posedge mgmt_clk);
        #1;
        if ((state != 4'd5) || !reconfig_write) begin
            $fatal(1, "retry did not reconfigure after the full drain guard");
        end

        pll_locked = 1'b1;
        wait_complete();
        if (error || !current_valid || (current_hz != 32'd100000000)
         || (current_profile != 2'd0) || (done_sequence != 32'h16)) begin
            $fatal(1, "error-hold retry result mismatch");
        end

        @(negedge mgmt_clk);
        reset = 1'b1;
        pll_locked = 1'b0;
        memory_drain_ack = 1'b0;
        repeat (3) @(posedge mgmt_clk);
        @(negedge mgmt_clk);
        reset = 1'b0;
        wait_complete();
        if ((state != 4'd8) || !error || (error_code != 32'd5)
         || current_valid || !clock_change_req || !clock_reset_req) begin
            $fatal(1, "startup PLL timeout did not enter error hold");
        end

        pll_locked = 1'b1;
        memory_drain_ack = 1'b1;
        issue_request(32'd250000000, 32'h20);
        wait_complete();
        if (error || !current_valid || (current_hz != 32'd250000000)
         || (current_profile != 2'd3) || (done_sequence != 32'h20)) begin
            $fatal(1, "startup PLL timeout recovery mismatch");
        end

        $display("PASS: de10pro_dynamic_clock");
        $finish;
    end

endmodule
