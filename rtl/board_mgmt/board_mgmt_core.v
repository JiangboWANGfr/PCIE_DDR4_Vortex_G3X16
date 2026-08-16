`timescale 1ns/1ps

module board_mgmt_core #(
    parameter CLK_FREQ_HZ            = 50000000,
    parameter I2C_FREQ_HZ            = 100000,
    parameter I2C_TIMEOUT_CYCLES     = 2500000,
    parameter STARTUP_DELAY_CYCLES   = 2500000,
    parameter POLL_INTERVAL_CYCLES   = 50000000
) (
    input  wire        clk,
    input  wire        reset,

    inout  wire        temp_scl,
    inout  wire        temp_sda,
    inout  wire        fan_scl,
    inout  wire        fan_sda,
    inout  wire        power_scl,
    inout  wire        power_sda,
    output reg         snapshot_update,
    output reg  [31:0] snapshot_sequence,
    output reg  [8:0]  snapshot_valid,
    output reg  [15:0] temperature_snapshot,
    output reg  [7:0]  tach0_snapshot,
    output reg  [7:0]  tach1_snapshot,
    output reg  [23:0] input_power_snapshot,
    output reg  [23:0] core_power_snapshot,
    output wire        fan_full_on,
    output wire        fan_full_off,
    output wire        fan_state_valid,
    output wire [7:0]  fan_dac,
    input  wire [1:0]  fan_control_mode,
    input  wire [7:0]  fan_control_dac,
    input  wire        fan_control_update,

    input  wire        avs_read,
    input  wire        avs_write,
    input  wire [3:0]  avs_address,
    input  wire [31:0] avs_writedata,
    input  wire [3:0]  avs_byteenable,
    output reg  [31:0] avs_readdata,
    output reg         avs_readdatavalid,
    output wire        avs_waitrequest
);

    localparam [1:0] BUS_TEMP  = 2'd0;
    localparam [1:0] BUS_FAN   = 2'd1;
    localparam [1:0] BUS_POWER = 2'd2;

    localparam [4:0] STEP_FAN_CONFIG    = 5'd0;
    localparam [4:0] STEP_FAN_COUNT     = 5'd1;
    localparam [4:0] STEP_INPUT_CONFIG  = 5'd2;
    localparam [4:0] STEP_CORE_CONFIG   = 5'd3;
    localparam [4:0] STEP_TEMP_LOCAL    = 5'd4;
    localparam [4:0] STEP_TEMP_REMOTE   = 5'd5;
    localparam [4:0] STEP_POLICY_DAC    = 5'd6;
    localparam [4:0] STEP_POLICY_CONFIG = 5'd7;
    localparam [4:0] STEP_TACH0         = 5'd8;
    localparam [4:0] STEP_TACH1         = 5'd9;
    localparam [4:0] STEP_INPUT_SENSE   = 5'd10;
    localparam [4:0] STEP_INPUT_VIN     = 5'd11;
    localparam [4:0] STEP_INPUT_POWER   = 5'd12;
    localparam [4:0] STEP_CORE_SENSE    = 5'd13;
    localparam [4:0] STEP_CORE_VIN      = 5'd14;
    localparam [4:0] STEP_CORE_POWER    = 5'd15;
    localparam [4:0] STEP_FAULT_FULL_ON = 5'd16;
    localparam [4:0] STEP_COMMIT        = 5'd17;

    localparam [6:0] ADDRESS_TMP441        = 7'h1c;
    localparam [6:0] ADDRESS_MAX6651       = 7'h48;
    localparam [6:0] ADDRESS_LTC2945_INPUT = 7'h6a;
    localparam [6:0] ADDRESS_LTC2945_CORE  = 7'h6d;

    localparam [7:0] MAX6651_CONFIG_REGISTER = 8'h02;
    localparam [7:0] MAX6651_CONFIG_FULL_ON  = 8'h0a;
    localparam [7:0] MAX6651_CONFIG_FULL_OFF = 8'h1a;
    localparam [7:0] MAX6651_CONFIG_OPEN_LOOP = 8'h3a;
    localparam [7:0] MAX6651_DAC_REGISTER     = 8'h06;
    localparam [7:0] MAX6651_DAC_REDUCED      = 8'h20;
    localparam [7:0] MAX6651_COUNT_REGISTER  = 8'h16;
    localparam [7:0] MAX6651_COUNT_HALF_SEC  = 8'h01;
    localparam [7:0] LTC2945_CONTROL_REGISTER = 8'h00;
    localparam [7:0] LTC2945_CONTROL_DEFAULT  = 8'h05;

    localparam [1:0] FAN_MODE_UNKNOWN = 2'd0;
    localparam [1:0] FAN_MODE_FULL_ON = 2'd1;
    localparam [1:0] FAN_MODE_REDUCED = 2'd2;
    localparam [1:0] FAN_MODE_FULL_OFF = 2'd3;

    localparam [1:0] FAN_CONTROL_AUTO = 2'd0;
    localparam [1:0] FAN_CONTROL_FULL_ON = 2'd1;
    localparam [1:0] FAN_CONTROL_MANUAL_DAC = 2'd2;
    localparam [1:0] FAN_CONTROL_FULL_OFF = 2'd3;

    wire temp_scl_drive_low;
    wire temp_sda_drive_low;
    wire fan_scl_drive_low;
    wire fan_sda_drive_low;
    wire power_scl_drive_low;
    wire power_sda_drive_low;

    wire temp_busy;
    wire temp_done;
    wire [31:0] temp_read_data;
    wire [2:0] temp_read_count;
    wire temp_error_nack;
    wire temp_error_timeout;
    wire temp_error_bus_stuck;
    wire temp_recovery_performed;

    wire fan_busy;
    wire fan_done;
    wire [31:0] fan_read_data;
    wire [2:0] fan_read_count;
    wire fan_error_nack;
    wire fan_error_timeout;
    wire fan_error_bus_stuck;
    wire fan_recovery_performed;

    wire power_busy;
    wire power_done;
    wire [31:0] power_read_data;
    wire [2:0] power_read_count;
    wire power_error_nack;
    wire power_error_timeout;
    wire power_error_bus_stuck;
    wire power_recovery_performed;

    reg command_start;
    reg [1:0] command_bus;
    reg command_read;
    reg [6:0] command_device_address;
    reg [7:0] command_register_address;
    reg [7:0] command_write_data;
    reg [2:0] command_read_length;

    reg step_has_command;
    reg [1:0] step_bus;
    reg step_read;
    reg [6:0] step_device_address;
    reg [7:0] step_register_address;
    reg [7:0] step_write_data;
    reg [2:0] step_read_length;

    reg selected_done;
    reg [31:0] selected_read_data;
    reg [2:0] selected_read_count;
    reg selected_error_nack;
    reg selected_error_timeout;
    reg selected_error_bus_stuck;
    reg selected_recovery_performed;

    reg [31:0] startup_counter;
    reg [31:0] poll_counter;
    reg startup_complete;
    reg scheduler_running;
    reg scheduler_waiting;
    reg [4:0] scheduler_step;
    reg force_poll_pending;

    reg fan_full_on_configured;
    reg fan_count_configured;
    reg input_power_configured;
    reg core_power_configured;
    reg [1:0] fan_mode;
    reg [7:0] fan_config_value;
    reg [7:0] fan_dac_value;
    reg fan_dac_ready;
    reg failsafe_required;
    reg round_started_in_failsafe;
    reg round_fault;

    reg [15:0] temperature_shadow;
    reg [7:0] tach0_shadow;
    reg [7:0] tach1_shadow;
    reg [15:0] input_sense_shadow;
    reg [15:0] input_vin_shadow;
    reg [23:0] input_power_shadow;
    reg [15:0] core_sense_shadow;
    reg [15:0] core_vin_shadow;
    reg [23:0] core_power_shadow;
    reg temperature_local_valid;
    reg temperature_remote_valid;
    reg [8:0] round_valid;

    reg [15:0] input_sense_snapshot;
    reg [15:0] input_vin_snapshot;
    reg [15:0] core_sense_snapshot;
    reg [15:0] core_vin_snapshot;

    reg [15:0] error_count;
    reg [4:0] last_error_step;
    reg [1:0] last_error_bus;
    reg last_error_nack;
    reg last_error_timeout;
    reg last_error_bus_stuck;
    reg last_error_short_read;
    reg [2:0] error_bus_sticky;
    reg [2:0] recovery_bus_sticky;

    wire transaction_short_read;
    wire transaction_failed;
    wire clear_status_request;
    wire force_poll_request;
    wire fan_control_auto;
    wire fan_control_full_on;
    wire fan_control_manual_dac;
    wire fan_control_full_off;

    assign temp_scl = temp_scl_drive_low ? 1'b0 : 1'bz;
    assign temp_sda = temp_sda_drive_low ? 1'b0 : 1'bz;
    assign fan_scl = fan_scl_drive_low ? 1'b0 : 1'bz;
    assign fan_sda = fan_sda_drive_low ? 1'b0 : 1'bz;
    assign power_scl = power_scl_drive_low ? 1'b0 : 1'bz;
    assign power_sda = power_sda_drive_low ? 1'b0 : 1'bz;

    assign avs_waitrequest = 1'b0;
    assign fan_full_on = (fan_mode == FAN_MODE_FULL_ON);
    assign fan_full_off = (fan_mode == FAN_MODE_FULL_OFF);
    assign fan_state_valid = (fan_mode != FAN_MODE_UNKNOWN);
    assign fan_dac = fan_dac_value;
    assign fan_control_auto = (fan_control_mode == FAN_CONTROL_AUTO);
    assign fan_control_full_on = (fan_control_mode == FAN_CONTROL_FULL_ON);
    assign fan_control_manual_dac =
        (fan_control_mode == FAN_CONTROL_MANUAL_DAC);
    assign fan_control_full_off =
        (fan_control_mode == FAN_CONTROL_FULL_OFF);
    assign clear_status_request = avs_write
                                && (avs_address == 4'hf)
                                && avs_byteenable[0]
                                && avs_writedata[0];
    assign force_poll_request = (avs_write
                              && (avs_address == 4'hf)
                              && avs_byteenable[0]
                              && avs_writedata[1])
                              || fan_control_update;
    assign transaction_short_read = command_read
                                  && (selected_read_count != command_read_length);
    assign transaction_failed = selected_error_nack
                              || selected_error_timeout
                              || selected_error_bus_stuck
                              || transaction_short_read;

    board_mgmt_i2c_master #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .I2C_FREQ_HZ    (I2C_FREQ_HZ),
        .TIMEOUT_CYCLES (I2C_TIMEOUT_CYCLES)
    ) temp_i2c_master (
        .clk                  (clk),
        .reset                (reset),
        .cmd_valid            (command_start && (command_bus == BUS_TEMP)),
        .cmd_ready            (),
        .cmd_read             (command_read),
        .cmd_device_address   (command_device_address),
        .cmd_register_address (command_register_address),
        .cmd_write_data       (command_write_data),
        .cmd_read_length      (command_read_length),
        .busy                 (temp_busy),
        .done                 (temp_done),
        .read_data            (temp_read_data),
        .read_count           (temp_read_count),
        .error_nack           (temp_error_nack),
        .error_timeout        (temp_error_timeout),
        .error_bus_stuck      (temp_error_bus_stuck),
        .recovery_performed   (temp_recovery_performed),
        .scl_i                (temp_scl),
        .sda_i                (temp_sda),
        .scl_drive_low        (temp_scl_drive_low),
        .sda_drive_low        (temp_sda_drive_low)
    );

    board_mgmt_i2c_master #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .I2C_FREQ_HZ    (I2C_FREQ_HZ),
        .TIMEOUT_CYCLES (I2C_TIMEOUT_CYCLES)
    ) fan_i2c_master (
        .clk                  (clk),
        .reset                (reset),
        .cmd_valid            (command_start && (command_bus == BUS_FAN)),
        .cmd_ready            (),
        .cmd_read             (command_read),
        .cmd_device_address   (command_device_address),
        .cmd_register_address (command_register_address),
        .cmd_write_data       (command_write_data),
        .cmd_read_length      (command_read_length),
        .busy                 (fan_busy),
        .done                 (fan_done),
        .read_data            (fan_read_data),
        .read_count           (fan_read_count),
        .error_nack           (fan_error_nack),
        .error_timeout        (fan_error_timeout),
        .error_bus_stuck      (fan_error_bus_stuck),
        .recovery_performed   (fan_recovery_performed),
        .scl_i                (fan_scl),
        .sda_i                (fan_sda),
        .scl_drive_low        (fan_scl_drive_low),
        .sda_drive_low        (fan_sda_drive_low)
    );

    board_mgmt_i2c_master #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .I2C_FREQ_HZ    (I2C_FREQ_HZ),
        .TIMEOUT_CYCLES (I2C_TIMEOUT_CYCLES)
    ) power_i2c_master (
        .clk                  (clk),
        .reset                (reset),
        .cmd_valid            (command_start && (command_bus == BUS_POWER)),
        .cmd_ready            (),
        .cmd_read             (command_read),
        .cmd_device_address   (command_device_address),
        .cmd_register_address (command_register_address),
        .cmd_write_data       (command_write_data),
        .cmd_read_length      (command_read_length),
        .busy                 (power_busy),
        .done                 (power_done),
        .read_data            (power_read_data),
        .read_count           (power_read_count),
        .error_nack           (power_error_nack),
        .error_timeout        (power_error_timeout),
        .error_bus_stuck      (power_error_bus_stuck),
        .recovery_performed   (power_recovery_performed),
        .scl_i                (power_scl),
        .sda_i                (power_sda),
        .scl_drive_low        (power_scl_drive_low),
        .sda_drive_low        (power_sda_drive_low)
    );

    always @(*) begin
        step_has_command = 1'b1;
        step_bus = BUS_TEMP;
        step_read = 1'b0;
        step_device_address = 7'b0;
        step_register_address = 8'b0;
        step_write_data = 8'b0;
        step_read_length = 3'd1;

        case (scheduler_step)
            STEP_FAN_CONFIG: begin
                step_has_command = ~fan_full_on_configured
                                 || ((fan_control_full_on
                                   || (fan_control_auto
                                    && failsafe_required))
                                  && (fan_mode != FAN_MODE_FULL_ON));
                step_bus = BUS_FAN;
                step_device_address = ADDRESS_MAX6651;
                step_register_address = MAX6651_CONFIG_REGISTER;
                step_write_data = MAX6651_CONFIG_FULL_ON;
            end
            STEP_FAN_COUNT: begin
                step_has_command = fan_full_on_configured && ~fan_count_configured;
                step_bus = BUS_FAN;
                step_device_address = ADDRESS_MAX6651;
                step_register_address = MAX6651_COUNT_REGISTER;
                step_write_data = MAX6651_COUNT_HALF_SEC;
            end
            STEP_INPUT_CONFIG: begin
                step_has_command = ~input_power_configured;
                step_bus = BUS_POWER;
                step_device_address = ADDRESS_LTC2945_INPUT;
                step_register_address = LTC2945_CONTROL_REGISTER;
                step_write_data = LTC2945_CONTROL_DEFAULT;
            end
            STEP_CORE_CONFIG: begin
                step_has_command = ~core_power_configured;
                step_bus = BUS_POWER;
                step_device_address = ADDRESS_LTC2945_CORE;
                step_register_address = LTC2945_CONTROL_REGISTER;
                step_write_data = LTC2945_CONTROL_DEFAULT;
            end
            STEP_TEMP_LOCAL: begin
                step_bus = BUS_TEMP;
                step_read = 1'b1;
                step_device_address = ADDRESS_TMP441;
                step_register_address = 8'h00;
            end
            STEP_TEMP_REMOTE: begin
                step_bus = BUS_TEMP;
                step_read = 1'b1;
                step_device_address = ADDRESS_TMP441;
                step_register_address = 8'h01;
            end
            STEP_POLICY_DAC: begin
                if (fan_control_manual_dac) begin
                    step_has_command = (fan_mode != FAN_MODE_REDUCED)
                                     || (fan_dac_value != fan_control_dac);
                    step_write_data = fan_control_dac;
                end else begin
                    step_has_command = fan_control_auto
                                     && temperature_remote_valid
                                     && ~round_fault
                                     && ~round_started_in_failsafe
                                     && ~failsafe_required
                                     && (temperature_shadow[15:8] < 8'd55)
                                     && ((fan_mode != FAN_MODE_REDUCED)
                                      || (fan_dac_value
                                          != MAX6651_DAC_REDUCED));
                    step_write_data = MAX6651_DAC_REDUCED;
                end
                step_bus = BUS_FAN;
                step_device_address = ADDRESS_MAX6651;
                step_register_address = MAX6651_DAC_REGISTER;
            end
            STEP_POLICY_CONFIG: begin
                step_bus = BUS_FAN;
                step_device_address = ADDRESS_MAX6651;
                step_register_address = MAX6651_CONFIG_REGISTER;
                if (fan_control_full_on) begin
                    step_has_command = (fan_mode != FAN_MODE_FULL_ON);
                    step_write_data = MAX6651_CONFIG_FULL_ON;
                end else if (fan_control_full_off) begin
                    step_has_command = (fan_mode != FAN_MODE_FULL_OFF);
                    step_write_data = MAX6651_CONFIG_FULL_OFF;
                end else if (fan_control_manual_dac) begin
                    step_has_command = (fan_mode != FAN_MODE_REDUCED)
                                     && fan_dac_ready;
                    step_write_data = MAX6651_CONFIG_OPEN_LOOP;
                end else if (round_fault
                 || failsafe_required
                 || round_started_in_failsafe
                 || ~temperature_remote_valid
                 || (temperature_shadow[15:8] >= 8'd60)) begin
                    step_has_command = (fan_mode != FAN_MODE_FULL_ON);
                    step_write_data = MAX6651_CONFIG_FULL_ON;
                end else if (temperature_shadow[15:8] < 8'd55) begin
                    step_has_command = (fan_mode != FAN_MODE_REDUCED)
                                     && fan_dac_ready;
                    step_write_data = MAX6651_CONFIG_OPEN_LOOP;
                end else begin
                    step_has_command = 1'b0;
                end
            end
            STEP_TACH0: begin
                step_has_command = fan_full_on_configured;
                step_bus = BUS_FAN;
                step_read = 1'b1;
                step_device_address = ADDRESS_MAX6651;
                step_register_address = 8'h0c;
            end
            STEP_TACH1: begin
                step_has_command = fan_full_on_configured;
                step_bus = BUS_FAN;
                step_read = 1'b1;
                step_device_address = ADDRESS_MAX6651;
                step_register_address = 8'h0e;
            end
            STEP_INPUT_SENSE: begin
                step_bus = BUS_POWER;
                step_read = 1'b1;
                step_device_address = ADDRESS_LTC2945_INPUT;
                step_register_address = 8'h14;
                step_read_length = 3'd2;
            end
            STEP_INPUT_VIN: begin
                step_bus = BUS_POWER;
                step_read = 1'b1;
                step_device_address = ADDRESS_LTC2945_INPUT;
                step_register_address = 8'h1e;
                step_read_length = 3'd2;
            end
            STEP_INPUT_POWER: begin
                step_bus = BUS_POWER;
                step_read = 1'b1;
                step_device_address = ADDRESS_LTC2945_INPUT;
                step_register_address = 8'h05;
                step_read_length = 3'd3;
            end
            STEP_CORE_SENSE: begin
                step_bus = BUS_POWER;
                step_read = 1'b1;
                step_device_address = ADDRESS_LTC2945_CORE;
                step_register_address = 8'h14;
                step_read_length = 3'd2;
            end
            STEP_CORE_VIN: begin
                step_bus = BUS_POWER;
                step_read = 1'b1;
                step_device_address = ADDRESS_LTC2945_CORE;
                step_register_address = 8'h1e;
                step_read_length = 3'd2;
            end
            STEP_CORE_POWER: begin
                step_bus = BUS_POWER;
                step_read = 1'b1;
                step_device_address = ADDRESS_LTC2945_CORE;
                step_register_address = 8'h05;
                step_read_length = 3'd3;
            end
            STEP_FAULT_FULL_ON: begin
                step_has_command = fan_control_auto
                                 && (round_fault || failsafe_required)
                                 && (fan_mode != FAN_MODE_FULL_ON);
                step_bus = BUS_FAN;
                step_device_address = ADDRESS_MAX6651;
                step_register_address = MAX6651_CONFIG_REGISTER;
                step_write_data = MAX6651_CONFIG_FULL_ON;
            end
            default: begin
                step_has_command = 1'b0;
            end
        endcase
    end

    always @(*) begin
        selected_done = 1'b0;
        selected_read_data = 32'b0;
        selected_read_count = 3'b0;
        selected_error_nack = 1'b0;
        selected_error_timeout = 1'b0;
        selected_error_bus_stuck = 1'b0;
        selected_recovery_performed = 1'b0;

        case (command_bus)
            BUS_TEMP: begin
                selected_done = temp_done;
                selected_read_data = temp_read_data;
                selected_read_count = temp_read_count;
                selected_error_nack = temp_error_nack;
                selected_error_timeout = temp_error_timeout;
                selected_error_bus_stuck = temp_error_bus_stuck;
                selected_recovery_performed = temp_recovery_performed;
            end
            BUS_FAN: begin
                selected_done = fan_done;
                selected_read_data = fan_read_data;
                selected_read_count = fan_read_count;
                selected_error_nack = fan_error_nack;
                selected_error_timeout = fan_error_timeout;
                selected_error_bus_stuck = fan_error_bus_stuck;
                selected_recovery_performed = fan_recovery_performed;
            end
            BUS_POWER: begin
                selected_done = power_done;
                selected_read_data = power_read_data;
                selected_read_count = power_read_count;
                selected_error_nack = power_error_nack;
                selected_error_timeout = power_error_timeout;
                selected_error_bus_stuck = power_error_bus_stuck;
                selected_recovery_performed = power_recovery_performed;
            end
            default: begin
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            startup_counter <= 32'b0;
            poll_counter <= 32'b0;
            startup_complete <= 1'b0;
            scheduler_running <= 1'b0;
            scheduler_waiting <= 1'b0;
            scheduler_step <= STEP_FAN_CONFIG;
            force_poll_pending <= 1'b1;
            command_start <= 1'b0;
            command_bus <= BUS_FAN;
            command_read <= 1'b0;
            command_device_address <= 7'b0;
            command_register_address <= 8'b0;
            command_write_data <= 8'b0;
            command_read_length <= 3'd1;

            fan_full_on_configured <= 1'b0;
            fan_count_configured <= 1'b0;
            input_power_configured <= 1'b0;
            core_power_configured <= 1'b0;
            fan_mode <= FAN_MODE_UNKNOWN;
            fan_config_value <= 8'b0;
            fan_dac_value <= 8'b0;
            fan_dac_ready <= 1'b0;
            failsafe_required <= 1'b1;
            round_started_in_failsafe <= 1'b1;
            round_fault <= 1'b0;

            temperature_shadow <= 16'b0;
            tach0_shadow <= 8'b0;
            tach1_shadow <= 8'b0;
            input_sense_shadow <= 16'b0;
            input_vin_shadow <= 16'b0;
            input_power_shadow <= 24'b0;
            core_sense_shadow <= 16'b0;
            core_vin_shadow <= 16'b0;
            core_power_shadow <= 24'b0;
            temperature_local_valid <= 1'b0;
            temperature_remote_valid <= 1'b0;
            round_valid <= 9'b0;

            temperature_snapshot <= 16'b0;
            tach0_snapshot <= 8'b0;
            tach1_snapshot <= 8'b0;
            input_sense_snapshot <= 16'b0;
            input_vin_snapshot <= 16'b0;
            input_power_snapshot <= 24'b0;
            core_sense_snapshot <= 16'b0;
            core_vin_snapshot <= 16'b0;
            core_power_snapshot <= 24'b0;
            snapshot_valid <= 9'b0;
            snapshot_sequence <= 32'b0;
            snapshot_update <= 1'b0;

            error_count <= 16'b0;
            last_error_step <= 5'b0;
            last_error_bus <= 2'b0;
            last_error_nack <= 1'b0;
            last_error_timeout <= 1'b0;
            last_error_bus_stuck <= 1'b0;
            last_error_short_read <= 1'b0;
            error_bus_sticky <= 3'b0;
            recovery_bus_sticky <= 3'b0;

        end else begin
            command_start <= 1'b0;
            snapshot_update <= 1'b0;

            if (clear_status_request) begin
                error_count <= 16'b0;
                last_error_step <= 5'b0;
                last_error_bus <= 2'b0;
                last_error_nack <= 1'b0;
                last_error_timeout <= 1'b0;
                last_error_bus_stuck <= 1'b0;
                last_error_short_read <= 1'b0;
                error_bus_sticky <= 3'b0;
                recovery_bus_sticky <= 3'b0;
            end

            if (force_poll_request) begin
                force_poll_pending <= 1'b1;
            end

            if (!startup_complete) begin
                if ((STARTUP_DELAY_CYCLES <= 1)
                 || (startup_counter + 1'b1 >= STARTUP_DELAY_CYCLES)) begin
                    startup_complete <= 1'b1;
                    startup_counter <= 32'b0;
                end else begin
                    startup_counter <= startup_counter + 1'b1;
                end
            end

            if (!scheduler_running) begin
                if (startup_complete) begin
                    if (force_poll_pending
                     || force_poll_request
                     || (POLL_INTERVAL_CYCLES <= 1)
                     || (poll_counter + 1'b1 >= POLL_INTERVAL_CYCLES)) begin
                        scheduler_running <= 1'b1;
                        scheduler_waiting <= 1'b0;
                        scheduler_step <= STEP_FAN_CONFIG;
                        fan_dac_ready <= 1'b0;
                        round_started_in_failsafe <= failsafe_required;
                        round_fault <= 1'b0;
                        temperature_local_valid <= 1'b0;
                        temperature_remote_valid <= 1'b0;
                        round_valid <= 9'b0;
                        poll_counter <= 32'b0;
                        force_poll_pending <= 1'b0;
                    end else begin
                        poll_counter <= poll_counter + 1'b1;
                    end
                end
            end else if (scheduler_waiting) begin
                if (selected_done) begin
                    scheduler_waiting <= 1'b0;

                    if (selected_recovery_performed) begin
                        recovery_bus_sticky[command_bus] <= 1'b1;
                    end

                    if (transaction_failed) begin
                        failsafe_required <= 1'b1;
                        round_fault <= 1'b1;
                        if (error_count != 16'hffff) begin
                            error_count <= error_count + 1'b1;
                        end
                        last_error_step <= scheduler_step;
                        last_error_bus <= command_bus;
                        last_error_nack <= selected_error_nack;
                        last_error_timeout <= selected_error_timeout;
                        last_error_bus_stuck <= selected_error_bus_stuck;
                        last_error_short_read <= transaction_short_read;
                        error_bus_sticky[command_bus] <= 1'b1;
                    end else begin
                        case (scheduler_step)
                            STEP_FAN_CONFIG: begin
                                fan_full_on_configured <= 1'b1;
                                fan_mode <= FAN_MODE_FULL_ON;
                                fan_config_value <= MAX6651_CONFIG_FULL_ON;
                            end
                            STEP_FAN_COUNT: begin
                                fan_count_configured <= 1'b1;
                            end
                            STEP_INPUT_CONFIG: begin
                                input_power_configured <= 1'b1;
                            end
                            STEP_CORE_CONFIG: begin
                                core_power_configured <= 1'b1;
                            end
                            STEP_TEMP_LOCAL: begin
                                temperature_shadow[7:0] <= selected_read_data[7:0];
                                temperature_local_valid <= 1'b1;
                            end
                            STEP_TEMP_REMOTE: begin
                                temperature_shadow[15:8] <= selected_read_data[7:0];
                                temperature_remote_valid <= 1'b1;
                                if (temperature_local_valid) begin
                                    round_valid[0] <= 1'b1;
                                end
                            end
                            STEP_POLICY_DAC: begin
                                fan_dac_value <= command_write_data;
                                fan_dac_ready <= 1'b1;
                            end
                            STEP_POLICY_CONFIG: begin
                                fan_config_value <= command_write_data;
                                if (command_write_data == MAX6651_CONFIG_FULL_ON) begin
                                    fan_full_on_configured <= 1'b1;
                                    fan_mode <= FAN_MODE_FULL_ON;
                                end else if (command_write_data
                                         == MAX6651_CONFIG_FULL_OFF) begin
                                    fan_mode <= FAN_MODE_FULL_OFF;
                                end else begin
                                    fan_mode <= FAN_MODE_REDUCED;
                                end
                            end
                            STEP_TACH0: begin
                                tach0_shadow <= selected_read_data[7:0];
                                round_valid[1] <= 1'b1;
                            end
                            STEP_TACH1: begin
                                tach1_shadow <= selected_read_data[7:0];
                                round_valid[2] <= 1'b1;
                            end
                            STEP_INPUT_SENSE: begin
                                input_sense_shadow <= selected_read_data[15:0];
                                round_valid[3] <= 1'b1;
                            end
                            STEP_INPUT_VIN: begin
                                input_vin_shadow <= selected_read_data[15:0];
                                round_valid[4] <= 1'b1;
                            end
                            STEP_INPUT_POWER: begin
                                input_power_shadow <= selected_read_data[23:0];
                                round_valid[5] <= 1'b1;
                            end
                            STEP_CORE_SENSE: begin
                                core_sense_shadow <= selected_read_data[15:0];
                                round_valid[6] <= 1'b1;
                            end
                            STEP_CORE_VIN: begin
                                core_vin_shadow <= selected_read_data[15:0];
                                round_valid[7] <= 1'b1;
                            end
                            STEP_CORE_POWER: begin
                                core_power_shadow <= selected_read_data[23:0];
                                round_valid[8] <= 1'b1;
                            end
                            STEP_FAULT_FULL_ON: begin
                                fan_full_on_configured <= 1'b1;
                                fan_mode <= FAN_MODE_FULL_ON;
                                fan_config_value <= MAX6651_CONFIG_FULL_ON;
                            end
                            default: begin
                            end
                        endcase
                    end

                    scheduler_step <= scheduler_step + 1'b1;
                end
            end else if (scheduler_step == STEP_COMMIT) begin
                temperature_snapshot <= temperature_shadow;
                tach0_snapshot <= tach0_shadow;
                tach1_snapshot <= tach1_shadow;
                input_sense_snapshot <= input_sense_shadow;
                input_vin_snapshot <= input_vin_shadow;
                input_power_snapshot <= input_power_shadow;
                core_sense_snapshot <= core_sense_shadow;
                core_vin_snapshot <= core_vin_shadow;
                core_power_snapshot <= core_power_shadow;
                snapshot_valid <= round_fault ? 9'b0 : round_valid;
                snapshot_sequence <= snapshot_sequence + 1'b1;
                snapshot_update <= 1'b1;
                if (!round_fault && (round_valid == 9'h1ff)) begin
                    failsafe_required <= 1'b0;
                end
                scheduler_running <= 1'b0;
                poll_counter <= 32'b0;
            end else if (step_has_command) begin
                command_bus <= step_bus;
                command_read <= step_read;
                command_device_address <= step_device_address;
                command_register_address <= step_register_address;
                command_write_data <= step_write_data;
                command_read_length <= step_read_length;
                command_start <= 1'b1;
                scheduler_waiting <= 1'b1;
            end else begin
                scheduler_step <= scheduler_step + 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            avs_readdata <= 32'b0;
            avs_readdatavalid <= 1'b0;
        end else begin
            avs_readdatavalid <= avs_read;
            if (avs_read) begin
                case (avs_address)
                    4'h0: avs_readdata <= 32'h424d4754;
                    4'h1: avs_readdata <= 32'h01000305;
                    4'h2: avs_readdata <= {
                        7'b0,
                        snapshot_valid,
                        5'b0,
                        power_busy,
                        fan_busy,
                        temp_busy,
                        2'b0,
                        (snapshot_sequence != 0),
                        core_power_configured,
                        input_power_configured,
                        fan_full_on_configured,
                        startup_complete,
                        scheduler_running
                    };
                    4'h3: avs_readdata <= snapshot_sequence;
                    4'h4: avs_readdata <= {16'b0, temperature_snapshot};
                    4'h5: avs_readdata <= {16'b0, tach1_snapshot, tach0_snapshot};
                    4'h6: avs_readdata <= {16'b0, input_sense_snapshot};
                    4'h7: avs_readdata <= {16'b0, input_vin_snapshot};
                    4'h8: avs_readdata <= {8'b0, input_power_snapshot};
                    4'h9: avs_readdata <= {16'b0, core_sense_snapshot};
                    4'ha: avs_readdata <= {16'b0, core_vin_snapshot};
                    4'hb: avs_readdata <= {8'b0, core_power_snapshot};
                    4'hc: avs_readdata <= {
                        2'b0,
                        last_error_step[4],
                        error_bus_sticky,
                        last_error_short_read,
                        last_error_bus_stuck,
                        last_error_timeout,
                        last_error_nack,
                        last_error_bus,
                        last_error_step[3:0],
                        error_count
                    };
                    4'he: avs_readdata <= {
                        round_fault,
                        failsafe_required,
                        fan_dac_value,
                        fan_config_value,
                        fan_mode,
                        scheduler_step[4],
                        recovery_bus_sticky,
                        2'b0,
                        command_bus,
                        scheduler_step[3:0]
                    };
                    default: avs_readdata <= 32'b0;
                endcase
            end
        end
    end

endmodule
