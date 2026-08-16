`timescale 1ns/1ps

module tb_board_mgmt_core;

    reg clk;
    reg reset;
    tri1 temp_scl;
    tri1 temp_sda;
    tri1 fan_scl;
    tri1 fan_sda;
    tri1 power_scl;
    tri1 power_sda;
    reg avs_read;
    reg avs_write;
    reg [3:0] avs_address;
    reg [31:0] avs_writedata;
    reg [3:0] avs_byteenable;
    wire [31:0] avs_readdata;
    wire avs_readdatavalid;
    wire avs_waitrequest;
    wire snapshot_update;
    wire [31:0] snapshot_sequence;
    wire [8:0] snapshot_valid;
    wire [15:0] temperature_snapshot;
    wire [7:0] tach0_snapshot;
    wire [7:0] tach1_snapshot;
    wire [23:0] input_power_snapshot;
    wire [23:0] core_power_snapshot;
    wire fan_full_on;
    wire fan_state_valid;
    wire [7:0] fan_dac;
    reg temp_force_nack;
    reg fan_force_nack;
    reg input_power_force_nack;
    reg core_power_force_nack;
    reg [31:0] csr_value;
    reg snapshot_update_delayed;
    integer wait_cycles;
    integer snapshot_pulse_count;
    integer fan_write_count_before;

    board_mgmt_core #(
        .CLK_FREQ_HZ          (4000000),
        .I2C_FREQ_HZ          (100000),
        .I2C_TIMEOUT_CYCLES   (1000),
        .STARTUP_DELAY_CYCLES (8),
        .POLL_INTERVAL_CYCLES (1000000)
    ) dut (
        .clk                   (clk),
        .reset                 (reset),
        .temp_scl              (temp_scl),
        .temp_sda              (temp_sda),
        .fan_scl               (fan_scl),
        .fan_sda               (fan_sda),
        .power_scl             (power_scl),
        .power_sda             (power_sda),
        .snapshot_update        (snapshot_update),
        .snapshot_sequence      (snapshot_sequence),
        .snapshot_valid         (snapshot_valid),
        .temperature_snapshot   (temperature_snapshot),
        .tach0_snapshot         (tach0_snapshot),
        .tach1_snapshot         (tach1_snapshot),
        .input_power_snapshot   (input_power_snapshot),
        .core_power_snapshot    (core_power_snapshot),
        .fan_full_on            (fan_full_on),
        .fan_state_valid        (fan_state_valid),
        .fan_dac                (fan_dac),
        .avs_read              (avs_read),
        .avs_write             (avs_write),
        .avs_address           (avs_address),
        .avs_writedata         (avs_writedata),
        .avs_byteenable        (avs_byteenable),
        .avs_readdata          (avs_readdata),
        .avs_readdatavalid     (avs_readdatavalid),
        .avs_waitrequest       (avs_waitrequest)
    );

    tb_i2c_slave_model #(
        .DEVICE_ADDRESS (7'h1c)
    ) temperature_device (
        .force_nack (temp_force_nack),
        .scl        (temp_scl),
        .sda        (temp_sda)
    );

    tb_i2c_slave_model #(
        .DEVICE_ADDRESS (7'h48)
    ) fan_device (
        .force_nack (fan_force_nack),
        .scl        (fan_scl),
        .sda        (fan_sda)
    );

    tb_i2c_slave_model #(
        .DEVICE_ADDRESS (7'h6a)
    ) input_power_device (
        .force_nack (input_power_force_nack),
        .scl        (power_scl),
        .sda        (power_sda)
    );

    tb_i2c_slave_model #(
        .DEVICE_ADDRESS (7'h6d)
    ) core_power_device (
        .force_nack (core_power_force_nack),
        .scl        (power_scl),
        .sda        (power_sda)
    );

    always begin
        #125 clk = ~clk;
    end

    always @(posedge clk) begin
        if (reset) begin
            snapshot_update_delayed <= 1'b0;
            snapshot_pulse_count <= 0;
        end else begin
            if (snapshot_update && snapshot_update_delayed) begin
                $fatal(1, "snapshot_update lasted more than one cycle");
            end
            if (snapshot_update) begin
                snapshot_pulse_count <= snapshot_pulse_count + 1;
            end
            snapshot_update_delayed <= snapshot_update;
        end
    end

    task read_csr;
        input [3:0] address_value;
        output [31:0] data_value;
        begin
            @(negedge clk);
            avs_address = address_value;
            avs_read = 1'b1;
            @(posedge clk);
            #1;
            if (!avs_readdatavalid) begin
                $fatal(1, "missing Avalon read response at address %x", address_value);
            end
            data_value = avs_readdata;
            @(negedge clk);
            avs_read = 1'b0;
        end
    endtask

    task force_poll;
        begin
            @(negedge clk);
            avs_address = 4'hf;
            avs_writedata = 32'h00000002;
            avs_byteenable = 4'h1;
            avs_write = 1'b1;
            @(negedge clk);
            avs_write = 1'b0;
            avs_byteenable = 4'hf;
        end
    endtask

    task wait_for_snapshot;
        input [31:0] expected_sequence;
        begin
            wait_cycles = 0;
            while ((snapshot_sequence < expected_sequence) && (wait_cycles < 300000)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (snapshot_sequence !== expected_sequence) begin
                $fatal(1, "snapshot %0d did not complete, sequence=%0d",
                    expected_sequence, snapshot_sequence);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        avs_read = 1'b0;
        avs_write = 1'b0;
        avs_address = 4'b0;
        avs_writedata = 32'b0;
        avs_byteenable = 4'hf;
        temp_force_nack = 1'b0;
        fan_force_nack = 1'b0;
        input_power_force_nack = 1'b0;
        core_power_force_nack = 1'b0;

        temperature_device.memory[8'h00] = 8'h19;
        temperature_device.memory[8'h01] = 8'h41;
        fan_device.memory[8'h0c] = 8'h28;
        fan_device.memory[8'h0e] = 8'h2a;
        input_power_device.memory[8'h14] = 8'ha1;
        input_power_device.memory[8'h15] = 8'hb2;
        input_power_device.memory[8'h1e] = 8'hc3;
        input_power_device.memory[8'h1f] = 8'hd4;
        input_power_device.memory[8'h05] = 8'h01;
        input_power_device.memory[8'h06] = 8'h23;
        input_power_device.memory[8'h07] = 8'h45;
        core_power_device.memory[8'h14] = 8'h11;
        core_power_device.memory[8'h15] = 8'h22;
        core_power_device.memory[8'h1e] = 8'h33;
        core_power_device.memory[8'h1f] = 8'h44;
        core_power_device.memory[8'h05] = 8'h56;
        core_power_device.memory[8'h06] = 8'h78;
        core_power_device.memory[8'h07] = 8'h9a;

        repeat (8) begin
            @(posedge clk);
        end
        @(negedge clk);
        if (fan_state_valid) begin
            $fatal(1, "fan state became valid before an acknowledged CONFIG write");
        end
        reset = 1'b0;

        wait_for_snapshot(32'd1);

        if ((fan_device.first_write_register !== 8'h02)
         || (fan_device.first_write_data !== 8'h0a)) begin
            $fatal(1, "first fan command was not CONFIG=0x0a: reg=%02x data=%02x",
                fan_device.first_write_register, fan_device.first_write_data);
        end
        if (fan_device.memory[8'h16] !== 8'h01) begin
            $fatal(1, "fan count-time initialization mismatch");
        end
        if ((fan_device.write_count !== 2) || !fan_state_valid || !fan_full_on
         || (fan_dac !== 8'h00)) begin
            $fatal(1, "initial full-on fan state mismatch");
        end
        if ((input_power_device.memory[8'h00] !== 8'h05)
         || (core_power_device.memory[8'h00] !== 8'h05)) begin
            $fatal(1, "LTC2945 initialization mismatch");
        end

        read_csr(4'h0, csr_value);
        if (csr_value !== 32'h424d4754) begin
            $fatal(1, "CSR identification mismatch: %08x", csr_value);
        end
        read_csr(4'h2, csr_value);
        if ((csr_value[24:16] !== 9'h1ff) || (csr_value[5:1] !== 5'b11111)) begin
            $fatal(1, "CSR status mismatch: %08x", csr_value);
        end
        read_csr(4'h3, csr_value);
        if (csr_value !== 32'd1) begin
            $fatal(1, "snapshot sequence mismatch: %08x", csr_value);
        end
        read_csr(4'h4, csr_value);
        if (csr_value !== 32'h00004119) begin
            $fatal(1, "temperature snapshot mismatch: %08x", csr_value);
        end
        read_csr(4'h5, csr_value);
        if (csr_value !== 32'h00002a28) begin
            $fatal(1, "tachometer snapshot mismatch: %08x", csr_value);
        end
        read_csr(4'h6, csr_value);
        if (csr_value !== 32'h0000a1b2) begin
            $fatal(1, "input sense snapshot mismatch: %08x", csr_value);
        end
        read_csr(4'h7, csr_value);
        if (csr_value !== 32'h0000c3d4) begin
            $fatal(1, "input VIN snapshot mismatch: %08x", csr_value);
        end
        read_csr(4'h8, csr_value);
        if (csr_value !== 32'h00012345) begin
            $fatal(1, "input power snapshot mismatch: %08x", csr_value);
        end
        read_csr(4'h9, csr_value);
        if (csr_value !== 32'h00001122) begin
            $fatal(1, "core sense snapshot mismatch: %08x", csr_value);
        end
        read_csr(4'ha, csr_value);
        if (csr_value !== 32'h00003344) begin
            $fatal(1, "core VIN snapshot mismatch: %08x", csr_value);
        end
        read_csr(4'hb, csr_value);
        if (csr_value !== 32'h0056789a) begin
            $fatal(1, "core power snapshot mismatch: %08x", csr_value);
        end
        read_csr(4'hc, csr_value);
        if (csr_value !== 32'b0) begin
            $fatal(1, "unexpected I2C error status: %08x", csr_value);
        end
        if ((snapshot_valid !== 9'h1ff)
         || (temperature_snapshot !== 16'h4119)
         || (tach0_snapshot !== 8'h28)
         || (tach1_snapshot !== 8'h2a)
         || (input_power_snapshot !== 24'h012345)
         || (core_power_snapshot !== 24'h56789a)) begin
            $fatal(1, "snapshot output interface mismatch");
        end

        temperature_device.memory[8'h01] = 8'd50;
        fan_write_count_before = fan_device.write_count;
        force_poll();
        wait_for_snapshot(32'd2);
        if (fan_device.write_count !== fan_write_count_before + 2) begin
            $fatal(1, "low-temperature transition did not issue two fan writes");
        end
        if ((fan_device.write_register_log[fan_write_count_before] !== 8'h06)
         || (fan_device.write_data_log[fan_write_count_before] !== 8'h20)
         || (fan_device.write_register_log[fan_write_count_before + 1] !== 8'h02)
         || (fan_device.write_data_log[fan_write_count_before + 1] !== 8'h3a)) begin
            $fatal(1, "reduced-mode writes were not DAC=0x20 then CONFIG=0x3a");
        end
        if (fan_full_on || (fan_dac !== 8'h20)
         || (fan_device.memory[8'h02] !== 8'h3a)) begin
            $fatal(1, "low-temperature reduced mode mismatch");
        end
        read_csr(4'he, csr_value);
        if ((csr_value[13:12] !== 2'd2)
         || (csr_value[21:14] !== 8'h3a)
         || (csr_value[29:22] !== 8'h20)
         || csr_value[31:30] != 2'b00) begin
            $fatal(1, "fan state CSR mismatch in reduced mode: %08x", csr_value);
        end

        temperature_device.memory[8'h01] = 8'd57;
        fan_write_count_before = fan_device.write_count;
        force_poll();
        wait_for_snapshot(32'd3);
        if ((fan_device.write_count !== fan_write_count_before) || fan_full_on) begin
            $fatal(1, "55-59 degree hysteresis did not hold reduced mode");
        end

        temperature_device.memory[8'h01] = 8'd60;
        fan_write_count_before = fan_device.write_count;
        force_poll();
        wait_for_snapshot(32'd4);
        if ((fan_device.write_count !== fan_write_count_before + 1)
         || (fan_device.write_register_log[fan_write_count_before] !== 8'h02)
         || (fan_device.write_data_log[fan_write_count_before] !== 8'h0a)
         || !fan_full_on) begin
            $fatal(1, "60 degree threshold did not restore full-on mode");
        end

        temperature_device.memory[8'h01] = 8'd50;
        force_poll();
        wait_for_snapshot(32'd5);
        if (fan_full_on || (fan_device.memory[8'h02] !== 8'h3a)) begin
            $fatal(1, "second low-temperature transition did not reduce speed");
        end

        input_power_force_nack = 1'b1;
        fan_write_count_before = fan_device.write_count;
        force_poll();
        wait_for_snapshot(32'd6);
        if ((fan_device.write_count !== fan_write_count_before + 1)
         || (fan_device.write_register_log[fan_write_count_before] !== 8'h02)
         || (fan_device.write_data_log[fan_write_count_before] !== 8'h0a)
         || !fan_state_valid || !fan_full_on) begin
            $fatal(1, "I2C fault did not force a valid full-on mode");
        end
        read_csr(4'hc, csr_value);
        if ((csr_value[15:0] == 0) || !csr_value[28]) begin
            $fatal(1, "power-bus fault was not recorded: %08x", csr_value);
        end
        read_csr(4'he, csr_value);
        if (!csr_value[31] || !csr_value[30]
         || (csr_value[13:12] !== 2'd1)
         || (csr_value[21:14] !== 8'h0a)) begin
            $fatal(1, "fail-safe fan state CSR mismatch: %08x", csr_value);
        end

        fan_write_count_before = fan_device.write_count;
        force_poll();
        wait_for_snapshot(32'd7);
        if ((fan_device.write_count !== fan_write_count_before)
         || !fan_full_on || (fan_device.memory[8'h02] !== 8'h0a)) begin
            $fatal(1, "persistent late I2C fault allowed fan-speed writes");
        end
        read_csr(4'he, csr_value);
        if (!csr_value[31] || !csr_value[30]) begin
            $fatal(1, "persistent late I2C fault did not retain fail-safe: %08x",
                csr_value);
        end

        input_power_force_nack = 1'b0;
        fan_write_count_before = fan_device.write_count;
        force_poll();
        wait_for_snapshot(32'd8);
        if ((fan_device.write_count !== fan_write_count_before)
         || !fan_full_on || (fan_device.memory[8'h02] !== 8'h0a)) begin
            $fatal(1, "clean recovery round did not remain full-on");
        end
        read_csr(4'he, csr_value);
        if (csr_value[31] || csr_value[30]) begin
            $fatal(1, "complete healthy round did not clear fail-safe: %08x",
                csr_value);
        end

        fan_write_count_before = fan_device.write_count;
        force_poll();
        wait_for_snapshot(32'd9);
        if ((fan_device.write_count !== fan_write_count_before + 2)
         || (fan_device.write_register_log[fan_write_count_before] !== 8'h06)
         || (fan_device.write_data_log[fan_write_count_before] !== 8'h20)
         || (fan_device.write_register_log[fan_write_count_before + 1] !== 8'h02)
         || (fan_device.write_data_log[fan_write_count_before + 1] !== 8'h3a)
         || fan_full_on) begin
            $fatal(1, "fan did not reduce until after a complete healthy round");
        end

        @(negedge clk);
        if (snapshot_pulse_count !== 9) begin
            $fatal(1, "snapshot_update pulse count mismatch: %0d", snapshot_pulse_count);
        end

        reset = 1'b1;
        fan_force_nack = 1'b1;
        repeat (8) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        wait (dut.scheduler_running && (dut.scheduler_step == 5'd1));
        @(negedge clk);
        fan_force_nack = 1'b0;
        wait_for_snapshot(32'd1);
        if ((snapshot_valid !== 9'b0) || !fan_state_valid || !fan_full_on) begin
            $fatal(1, "faulted initialization round was reported valid");
        end

        force_poll();
        wait_for_snapshot(32'd2);
        if ((snapshot_valid !== 9'h1ff)
         || (fan_device.memory[8'h16] !== 8'h01)) begin
            $fatal(1, "healthy round did not recover initialization validity");
        end

        $display("PASS: board_mgmt_core");
        $finish;
    end

endmodule
