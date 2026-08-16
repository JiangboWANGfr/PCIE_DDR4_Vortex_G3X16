`timescale 1ns/1ps

module tb_board_mgmt_i2c_master;

    reg clk;
    reg reset;
    reg cmd_valid;
    wire cmd_ready;
    reg cmd_read;
    reg [6:0] cmd_device_address;
    reg [7:0] cmd_register_address;
    reg [7:0] cmd_write_data;
    reg [2:0] cmd_read_length;
    wire busy;
    wire done;
    wire [31:0] read_data;
    wire [2:0] read_count;
    wire error_nack;
    wire error_timeout;
    wire error_bus_stuck;
    wire recovery_performed;
    wire drive_fault_scl;
    wire drive_fault_sda;
    wire deaf_done;
    wire deaf_drive_fault_scl;
    wire deaf_drive_fault_sda;
    wire scl_drive_low;
    wire sda_drive_low;
    tri1 scl;
    tri1 sda;
    reg hold_scl_low;
    reg hold_sda_low;
    reg force_nack;
    integer wait_cycles;

    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;
    assign scl = hold_scl_low ? 1'b0 : 1'bz;
    assign sda = hold_sda_low ? 1'b0 : 1'bz;

    board_mgmt_i2c_master #(
        .CLK_FREQ_HZ    (4000000),
        .I2C_FREQ_HZ    (100000),
        .TIMEOUT_CYCLES (80)
    ) dut (
        .clk                  (clk),
        .reset                (reset),
        .cmd_valid            (cmd_valid),
        .cmd_ready            (cmd_ready),
        .cmd_read             (cmd_read),
        .cmd_device_address   (cmd_device_address),
        .cmd_register_address (cmd_register_address),
        .cmd_write_data       (cmd_write_data),
        .cmd_read_length      (cmd_read_length),
        .busy                 (busy),
        .done                 (done),
        .read_data            (read_data),
        .read_count           (read_count),
        .error_nack           (error_nack),
        .error_timeout        (error_timeout),
        .error_bus_stuck      (error_bus_stuck),
        .drive_fault_scl      (drive_fault_scl),
        .drive_fault_sda      (drive_fault_sda),
        .recovery_performed   (recovery_performed),
        .scl_i                (scl),
        .sda_i                (sda),
        .scl_drive_low        (scl_drive_low),
        .sda_drive_low        (sda_drive_low)
    );

    // Same commands, but the pad inputs are stuck high: this models a bus the
    // master drives without the levels ever reaching the wire.
    board_mgmt_i2c_master #(
        .CLK_FREQ_HZ    (4000000),
        .I2C_FREQ_HZ    (100000),
        .TIMEOUT_CYCLES (80)
    ) deaf (
        .clk                  (clk),
        .reset                (reset),
        .cmd_valid            (cmd_valid),
        .cmd_ready            (),
        .cmd_read             (cmd_read),
        .cmd_device_address   (cmd_device_address),
        .cmd_register_address (cmd_register_address),
        .cmd_write_data       (cmd_write_data),
        .cmd_read_length      (cmd_read_length),
        .busy                 (),
        .done                 (deaf_done),
        .read_data            (),
        .read_count           (),
        .error_nack           (),
        .error_timeout        (),
        .error_bus_stuck      (),
        .error_byte_kind      (),
        .drive_fault_scl      (deaf_drive_fault_scl),
        .drive_fault_sda      (deaf_drive_fault_sda),
        .recovery_performed   (),
        .scl_i                (1'b1),
        .sda_i                (1'b1),
        .scl_drive_low        (),
        .sda_drive_low        ()
    );

    tb_i2c_slave_model #(
        .DEVICE_ADDRESS (7'h50)
    ) slave (
        .force_nack (force_nack),
        .scl        (scl),
        .sda        (sda)
    );

    always begin
        #125 clk = ~clk;
    end

    task issue_command;
        input       is_read;
        input [7:0] register_value;
        input [7:0] write_value;
        input [2:0] length_value;
        begin
            while (!cmd_ready) begin
                @(posedge clk);
            end
            @(negedge clk);
            cmd_read = is_read;
            cmd_device_address = 7'h50;
            cmd_register_address = register_value;
            cmd_write_data = write_value;
            cmd_read_length = length_value;
            cmd_valid = 1'b1;
            @(negedge clk);
            cmd_valid = 1'b0;

            wait_cycles = 0;
            while (!done && (wait_cycles < 20000)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!done) begin
                $fatal(1, "I2C command did not complete");
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        cmd_valid = 1'b0;
        cmd_read = 1'b0;
        cmd_device_address = 7'b0;
        cmd_register_address = 8'b0;
        cmd_write_data = 8'b0;
        cmd_read_length = 3'b0;
        hold_scl_low = 1'b0;
        hold_sda_low = 1'b0;
        force_nack = 1'b0;

        slave.memory[8'h20] = 8'h12;
        slave.memory[8'h21] = 8'h34;
        slave.memory[8'h22] = 8'h56;

        repeat (8) begin
            @(posedge clk);
        end
        @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        hold_scl_low = 1'b1;
        hold_sda_low = 1'b1;
        @(posedge clk);
        #1;
        if ((dut.scl_sync !== 2'b10) || (dut.sda_sync !== 2'b10)) begin
            $fatal(1, "I2C inputs bypassed the first synchronizer stage");
        end
        @(posedge clk);
        #1;
        if ((dut.scl_sync !== 2'b00) || (dut.sda_sync !== 2'b00)) begin
            $fatal(1, "I2C low inputs did not cross both synchronizer stages");
        end
        @(negedge clk);
        hold_scl_low = 1'b0;
        hold_sda_low = 1'b0;
        @(posedge clk);
        #1;
        if ((dut.scl_sync !== 2'b01) || (dut.sda_sync !== 2'b01)) begin
            $fatal(1, "I2C inputs bypassed the release synchronizer stage");
        end
        @(posedge clk);
        #1;
        if ((dut.scl_sync !== 2'b11) || (dut.sda_sync !== 2'b11)) begin
            $fatal(1, "I2C released inputs did not cross both synchronizer stages");
        end

        issue_command(1'b0, 8'h10, 8'hab, 3'd1);
        if (error_nack || error_timeout || error_bus_stuck) begin
            $fatal(1, "write command reported an error");
        end
        if (slave.memory[8'h10] !== 8'hab) begin
            $fatal(1, "write data mismatch: %02x", slave.memory[8'h10]);
        end

        issue_command(1'b1, 8'h20, 8'b0, 3'd3);
        if (error_nack || error_timeout || error_bus_stuck) begin
            $fatal(1, "read command reported an error");
        end
        if ((read_count !== 3'd3) || (read_data[23:0] !== 24'h123456)) begin
            $fatal(1, "read mismatch: count=%0d data=%08x", read_count, read_data);
        end

        force_nack = 1'b1;
        issue_command(1'b0, 8'h11, 8'h5a, 3'd1);
        force_nack = 1'b0;
        if (!error_nack || error_timeout) begin
            $fatal(1, "NACK was not reported correctly");
        end

        hold_sda_low = 1'b1;
        repeat (3) @(posedge clk);
        fork
            begin
                repeat (3) begin
                    @(posedge scl);
                end
                hold_sda_low = 1'b0;
            end
            begin
                issue_command(1'b1, 8'h20, 8'b0, 3'd1);
            end
        join
        if (!recovery_performed || error_nack || error_timeout || error_bus_stuck) begin
            $fatal(1, "recoverable stuck bus failed: recovery=%b nack=%b timeout=%b stuck=%b state=%0d",
                recovery_performed, error_nack, error_timeout, error_bus_stuck, dut.state);
        end
        if (read_data[7:0] !== 8'h12) begin
            $fatal(1, "post-recovery read mismatch: %08x", read_data);
        end

        hold_scl_low = 1'b1;
        repeat (3) @(posedge clk);
        issue_command(1'b0, 8'h12, 8'ha5, 3'd1);
        hold_scl_low = 1'b0;
        if (!error_timeout || !recovery_performed) begin
            $fatal(1, "clock-low timeout was not reported");
        end

        if (drive_fault_scl || drive_fault_sda) begin
            $fatal(1, "drive fault reported on a healthy bus: scl=%b sda=%b",
                drive_fault_scl, drive_fault_sda);
        end
        if (!deaf_drive_fault_scl || !deaf_drive_fault_sda) begin
            $fatal(1, "drive fault not reported when the bus ignores the drive: scl=%b sda=%b",
                deaf_drive_fault_scl, deaf_drive_fault_sda);
        end

        $display("PASS: board_mgmt_i2c_master");
        $finish;
    end

endmodule
