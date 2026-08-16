`timescale 1ns/1ps

module tb_de10pro_board_manager;

    reg clk;
    reg reset;
    reg avs_chipselect;
    reg avs_read;
    reg avs_write;
    reg [7:0] avs_address;
    reg [31:0] avs_writedata;
    reg [3:0] avs_byteenable;
    wire [31:0] avs_readdata;
    wire avs_readdatavalid;
    wire avs_waitrequest;
    tri1 temp_scl;
    tri1 temp_sda;
    tri1 fan_scl;
    tri1 fan_sda;
    tri1 power_scl;
    tri1 power_sda;
    wire clock_change_req;
    wire clock_reset_req;
    reg clock_change_ack;
    reg clock_reset_ack;
    wire memory_drain_req;
    reg memory_drain_ack;
    reg pll_locked;
    reg vortex_clk;
    wire [9:0] reconfig_address;
    wire reconfig_read;
    wire reconfig_write;
    wire [7:0] reconfig_writedata;
    reg [7:0] reconfig_readdata;
    reg reconfig_waitrequest;

    integer reconfig_delay;
    reg [7:0] observed_profile;
    reg [31:0] read_value;

    de10pro_board_manager dut (
        .clk                    (clk),
        .reset                  (reset),
        .avs_chipselect         (avs_chipselect),
        .avs_read               (avs_read),
        .avs_write              (avs_write),
        .avs_address            (avs_address),
        .avs_writedata          (avs_writedata),
        .avs_byteenable         (avs_byteenable),
        .avs_readdata           (avs_readdata),
        .avs_readdatavalid      (avs_readdatavalid),
        .avs_waitrequest        (avs_waitrequest),
        .temp_scl               (temp_scl),
        .temp_sda               (temp_sda),
        .fan_scl                (fan_scl),
        .fan_sda                (fan_sda),
        .power_scl              (power_scl),
        .power_sda              (power_sda),
        .clock_change_req       (clock_change_req),
        .clock_reset_req        (clock_reset_req),
        .clock_change_ack       (clock_change_ack),
        .clock_reset_ack        (clock_reset_ack),
        .memory_drain_req       (memory_drain_req),
        .memory_drain_ack       (memory_drain_ack),
        .pll_locked             (pll_locked),
        .vortex_clk             (vortex_clk),
        .reconfig_address       (reconfig_address),
        .reconfig_read          (reconfig_read),
        .reconfig_write         (reconfig_write),
        .reconfig_writedata     (reconfig_writedata),
        .reconfig_readdata      (reconfig_readdata),
        .reconfig_waitrequest   (reconfig_waitrequest)
    );

    defparam dut.dynamic_clock.QUIESCE_GUARD_CYCLES = 4;
    defparam dut.dynamic_clock.QUIESCE_TIMEOUT_CYCLES = 100;
    defparam dut.dynamic_clock.RECONFIG_TIMEOUT_CYCLES = 100;
    defparam dut.dynamic_clock.LOCK_STABLE_CYCLES = 3;

    always #5 clk = ~clk;
    always #2 vortex_clk = ~vortex_clk;

    always @(posedge clk) begin
        if (reset) begin
            clock_change_ack <= 1'b0;
            clock_reset_ack <= 1'b0;
            memory_drain_ack <= 1'b0;
        end else begin
            clock_change_ack <= clock_change_req;
            clock_reset_ack <= clock_reset_req;
            memory_drain_ack <= memory_drain_req;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            reconfig_waitrequest <= 1'b0;
            reconfig_delay <= 0;
            observed_profile <= 8'hff;
        end else if (reconfig_write && !reconfig_waitrequest) begin
            observed_profile <= reconfig_writedata;
            reconfig_waitrequest <= 1'b1;
            reconfig_delay <= 4;
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

    task write_csr;
        input [7:0] address_value;
        input [31:0] data_value;
        begin
            @(negedge clk);
            avs_chipselect = 1'b1;
            avs_write = 1'b1;
            avs_address = address_value;
            avs_writedata = data_value;
            avs_byteenable = 4'hf;
            @(negedge clk);
            avs_chipselect = 1'b0;
            avs_write = 1'b0;
        end
    endtask

    task read_csr;
        input [7:0] address_value;
        output [31:0] data_value;
        begin
            @(negedge clk);
            avs_chipselect = 1'b1;
            avs_read = 1'b1;
            avs_address = address_value;
            @(posedge clk);
            #1;
            if (!avs_readdatavalid) begin
                $fatal(1, "missing CSR response at %02x", address_value);
            end
            data_value = avs_readdata;
            @(negedge clk);
            avs_chipselect = 1'b0;
            avs_read = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        avs_chipselect = 1'b0;
        avs_read = 1'b0;
        avs_write = 1'b0;
        avs_address = 8'b0;
        avs_writedata = 32'b0;
        avs_byteenable = 4'hf;
        clock_change_ack = 1'b0;
        clock_reset_ack = 1'b0;
        memory_drain_ack = 1'b0;
        pll_locked = 1'b0;
        vortex_clk = 1'b0;
        reconfig_readdata = 8'b0;
        reconfig_waitrequest = 1'b0;
        reconfig_delay = 0;
        observed_profile = 8'hff;

        repeat (4) @(posedge clk);
        reset = 1'b0;
        repeat (3) @(posedge clk);
        pll_locked = 1'b1;
        while (dut.clock_busy) @(posedge clk);

        read_csr(8'h00, read_value);
        if (read_value != 32'h5658424d) $fatal(1, "bad manager magic");
        read_csr(8'h04, read_value);
        if (read_value != 32'h00010002) $fatal(1, "bad manager version");
        read_csr(8'h08, read_value);
        if (read_value != 32'h000007ff) $fatal(1, "bad capabilities");
        read_csr(8'h60, read_value);
        if (read_value != 32'h00002000) $fatal(1, "bad default fan control");
        write_csr(8'h60, 32'h00004402);
        read_csr(8'h60, read_value);
        if (read_value != 32'h00004402) $fatal(1, "bad manual fan control readback");
        read_csr(8'h20, read_value);
        if (read_value != 32'd208435) $fatal(1, "bad input power scale");
        read_csr(8'h24, read_value);
        if (read_value != 32'd5002440) $fatal(1, "bad core power scale");
        read_csr(8'h5c, read_value);
        if (read_value[1]) $fatal(1, "fan status valid before an acknowledged write");

        force dut.snapshot_sequence = 32'd7;
        force dut.snapshot_valid = 9'h1ff;
        force dut.temperature_snapshot = 16'hfe19;
        force dut.tach0_snapshot = 8'd40;
        force dut.input_power_snapshot = 24'h123456;
        force dut.core_power_snapshot = 24'h654321;
        force dut.fan_full_on = 1'b0;
        force dut.fan_full_off = 1'b0;
        force dut.fan_state_valid = 1'b0;
        force dut.fan_dac = 8'h20;

        read_csr(8'h10, read_value);
        if ($signed(read_value) != -2000) $fatal(1, "bad signed temperature");
        read_csr(8'h14, read_value);
        if (read_value != 32'd2400) $fatal(1, "bad fan RPM");
        read_csr(8'h18, read_value);
        if (read_value != 32'h00123456) $fatal(1, "bad input power raw");
        read_csr(8'h1c, read_value);
        if (read_value != 32'h00654321) $fatal(1, "bad core power raw");
        read_csr(8'h5c, read_value);
        if (read_value != 32'h00002000) $fatal(1, "bad fan control encoding");
        force dut.fan_state_valid = 1'b1;
        read_csr(8'h5c, read_value);
        if (read_value != 32'h00002002) $fatal(1, "bad valid fan status encoding");
        force dut.fan_full_off = 1'b1;
        read_csr(8'h5c, read_value);
        if (read_value != 32'h00002006) $fatal(1, "bad full-off fan status encoding");

        write_csr(8'h38, 32'd125000000);
        write_csr(8'h48, 32'h1234);
        write_csr(8'h40, 32'h1);
        wait (reconfig_write);
        pll_locked = 1'b0;
        wait (!reconfig_write);
        repeat (3) @(posedge clk);
        pll_locked = 1'b1;
        while (dut.clock_busy) @(posedge clk);
        if (observed_profile != 8'd1) $fatal(1, "profile mapping leaked/mismatch");
        read_csr(8'h3c, read_value);
        if (read_value != 32'd125000000) $fatal(1, "bad nominal clock");
        read_csr(8'h4c, read_value);
        if (read_value != 32'h1234) $fatal(1, "bad completed sequence");

        release dut.snapshot_sequence;
        release dut.snapshot_valid;
        release dut.temperature_snapshot;
        release dut.tach0_snapshot;
        release dut.input_power_snapshot;
        release dut.core_power_snapshot;
        release dut.fan_full_on;
        release dut.fan_full_off;
        release dut.fan_state_valid;
        release dut.fan_dac;

        $display("PASS: de10pro_board_manager");
        $finish;
    end

endmodule
