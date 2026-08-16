`timescale 1ns/1ps

module de10pro_board_manager #(
    parameter MGMT_CLK_HZ = 50000000,
    parameter TELEMETRY_POLL_CYCLES = 5000000
) (
    input  wire        clk,
    input  wire        reset,

    input  wire        avs_chipselect,
    input  wire        avs_read,
    input  wire        avs_write,
    input  wire [7:0]  avs_address,
    input  wire [31:0] avs_writedata,
    input  wire [3:0]  avs_byteenable,
    output reg  [31:0] avs_readdata,
    output reg         avs_readdatavalid,
    output wire        avs_waitrequest,

    inout  wire        temp_scl,
    inout  wire        temp_sda,
    inout  wire        fan_scl,
    inout  wire        fan_sda,
    inout  wire        power_scl,
    inout  wire        power_sda,
    output wire        clock_change_req,
    output wire        clock_reset_req,
    input  wire        clock_change_ack,
    input  wire        clock_reset_ack,

    output wire        memory_drain_req,
    input  wire        memory_drain_ack,

    input  wire        pll_locked,
    input  wire        vortex_clk,

    output wire [9:0]  reconfig_address,
    output wire        reconfig_read,
    output wire        reconfig_write,
    output wire [7:0]  reconfig_writedata,
    input  wire [7:0]  reconfig_readdata,
    input  wire        reconfig_waitrequest
);

    localparam [31:0] MAGIC_VALUE = 32'h5658424d;
    localparam [31:0] VERSION_VALUE = 32'h00010002;
    localparam [31:0] CAPABILITIES = 32'h000007ff;
    localparam [31:0] POWER_INPUT_LSB_NW = 32'd208435;
    localparam [31:0] POWER_CORE_LSB_NW = 32'd5002440;

    localparam [7:0] REG_MAGIC          = 8'h00;
    localparam [7:0] REG_VERSION        = 8'h04;
    localparam [7:0] REG_CAPABILITIES   = 8'h08;
    localparam [7:0] REG_STATUS         = 8'h0c;
    localparam [7:0] REG_TEMP_MC        = 8'h10;
    localparam [7:0] REG_FAN_RPM        = 8'h14;
    localparam [7:0] REG_POWER0_RAW     = 8'h18;
    localparam [7:0] REG_POWER1_RAW     = 8'h1c;
    localparam [7:0] REG_POWER0_LSB_NW  = 8'h20;
    localparam [7:0] REG_POWER1_LSB_NW  = 8'h24;
    localparam [7:0] REG_SAMPLE_COUNT   = 8'h28;
    localparam [7:0] REG_TIMESTAMP_LO   = 8'h2c;
    localparam [7:0] REG_TIMESTAMP_HI   = 8'h30;
    localparam [7:0] REG_TIMESTAMP_HZ   = 8'h34;
    localparam [7:0] REG_CLOCK_REQ_HZ   = 8'h38;
    localparam [7:0] REG_CLOCK_CUR_HZ   = 8'h3c;
    localparam [7:0] REG_CLOCK_COMMAND  = 8'h40;
    localparam [7:0] REG_CLOCK_STATUS   = 8'h44;
    localparam [7:0] REG_CLOCK_REQ_SEQ  = 8'h48;
    localparam [7:0] REG_CLOCK_DONE_SEQ = 8'h4c;
    localparam [7:0] REG_QUIESCE_STATUS = 8'h50;
    localparam [7:0] REG_CLOCK_ERROR    = 8'h54;
    localparam [7:0] REG_CLOCK_MEASURED = 8'h58;
    localparam [7:0] REG_FAN_STATUS     = 8'h5c;
    localparam [7:0] REG_FAN_CONTROL    = 8'h60;

    wire snapshot_update;
    wire [31:0] snapshot_sequence;
    wire [8:0] snapshot_valid;
    wire [15:0] temperature_snapshot;
    wire [7:0] tach0_snapshot;
    wire [7:0] tach1_snapshot;
    wire [23:0] input_power_snapshot;
    wire [23:0] core_power_snapshot;
    wire fan_full_on;
    wire fan_full_off;
    wire fan_state_valid;
    wire [7:0] fan_dac;
    wire [31:0] raw_readdata;
    wire raw_readdatavalid;
    wire raw_waitrequest;

    reg [63:0] timestamp_counter;
    reg [63:0] snapshot_timestamp;
    reg [31:0] requested_hz;
    reg [31:0] request_sequence;
    reg clock_apply;
    reg clock_clear_status;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] pll_locked_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] change_ack_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] memory_drain_ack_sync;

    wire clock_busy;
    wire clock_done;
    wire clock_error;
    wire [31:0] clock_error_code;
    wire [31:0] current_hz;
    wire current_valid;
    wire [31:0] clock_done_sequence;
    wire [1:0] current_profile;
    wire [3:0] clock_state;
    wire [31:0] measured_hz;

    wire telemetry_valid;
    wire telemetry_fault;
    wire signed [31:0] remote_temperature;
    wire signed [31:0] temperature_mc;
    wire [31:0] fan_rpm;
    wire [31:0] clock_status;
    wire [31:0] quiesce_status;
    wire telemetry_clear;
    wire command_write;
    wire fan_control_write;

    reg [1:0] fan_control_mode;
    reg [7:0] fan_control_dac;

    reg [31:0] read_data_mux;

    assign avs_waitrequest = 1'b0;
    assign telemetry_valid = (snapshot_sequence != 0)
                           && ((snapshot_valid & 9'h123) == 9'h123);
    assign telemetry_fault = (snapshot_sequence != 0) && !telemetry_valid;
    assign remote_temperature = {{24{temperature_snapshot[15]}},
                                 temperature_snapshot[15:8]};
    assign temperature_mc = remote_temperature * 32'sd1000;
    assign fan_rpm = tach0_snapshot * 32'd60;
    assign command_write = avs_chipselect && avs_write
                         && (avs_address == REG_CLOCK_COMMAND)
                         && avs_byteenable[0];
    assign telemetry_clear = command_write && avs_writedata[1];
    assign fan_control_write = avs_chipselect && avs_write
                             && (avs_address == REG_FAN_CONTROL);
    assign memory_drain_req = clock_change_req;
    assign clock_status = {
        24'b0,
        clock_reset_req,
        change_ack_sync[1] && memory_drain_ack_sync[1],
        clock_change_req,
        current_valid,
        pll_locked_sync[1],
        clock_error,
        clock_done,
        clock_busy
    };
    assign quiesce_status = {
        change_ack_sync[1] && memory_drain_ack_sync[1],
        28'b0,
        memory_drain_ack_sync[1],
        change_ack_sync[1],
        clock_change_req
    };

    board_mgmt_core #(
        .CLK_FREQ_HZ          (MGMT_CLK_HZ),
        .POLL_INTERVAL_CYCLES (TELEMETRY_POLL_CYCLES)
    ) telemetry (
        .clk                   (clk),
        .reset                 (reset),
        .temp_scl              (temp_scl),
        .temp_sda              (temp_sda),
        .fan_scl               (fan_scl),
        .fan_sda               (fan_sda),
        .power_scl             (power_scl),
        .power_sda             (power_sda),
        .snapshot_update       (snapshot_update),
        .snapshot_sequence     (snapshot_sequence),
        .snapshot_valid        (snapshot_valid),
        .temperature_snapshot  (temperature_snapshot),
        .tach0_snapshot        (tach0_snapshot),
        .tach1_snapshot        (tach1_snapshot),
        .input_power_snapshot  (input_power_snapshot),
        .core_power_snapshot   (core_power_snapshot),
        .fan_full_on           (fan_full_on),
        .fan_full_off          (fan_full_off),
        .fan_state_valid       (fan_state_valid),
        .fan_dac               (fan_dac),
        .fan_control_mode      (fan_control_mode),
        .fan_control_dac       (fan_control_dac),
        .fan_control_update    (fan_control_write),
        .avs_read              (1'b0),
        .avs_write             (telemetry_clear),
        .avs_address           (4'hf),
        .avs_writedata         (32'h00000001),
        .avs_byteenable        (4'h1),
        .avs_readdata          (raw_readdata),
        .avs_readdatavalid     (raw_readdatavalid),
        .avs_waitrequest       (raw_waitrequest)
    );

    de10pro_dynamic_clock #(
        .MGMT_CLK_HZ (MGMT_CLK_HZ)
    ) dynamic_clock (
        .mgmt_clk             (clk),
        .reset                (reset),
        .apply                (clock_apply),
        .clear_status         (clock_clear_status),
        .requested_hz         (requested_hz),
        .request_sequence     (request_sequence),
        .busy                 (clock_busy),
        .done                 (clock_done),
        .error                (clock_error),
        .error_code           (clock_error_code),
        .current_hz           (current_hz),
        .current_valid        (current_valid),
        .done_sequence        (clock_done_sequence),
        .current_profile      (current_profile),
        .state                (clock_state),
        .clock_change_req     (clock_change_req),
        .clock_reset_req      (clock_reset_req),
        .clock_change_ack     (clock_change_ack),
        .memory_drain_ack     (memory_drain_ack),
        .clock_reset_ack      (clock_reset_ack),
        .pll_locked           (pll_locked),
        .vortex_clk           (vortex_clk),
        .measured_hz          (measured_hz),
        .reconfig_address     (reconfig_address),
        .reconfig_read        (reconfig_read),
        .reconfig_write       (reconfig_write),
        .reconfig_writedata   (reconfig_writedata),
        .reconfig_readdata    (reconfig_readdata),
        .reconfig_waitrequest (reconfig_waitrequest)
    );

    always @(*) begin
        case (avs_address)
            REG_MAGIC:          read_data_mux = MAGIC_VALUE;
            REG_VERSION:        read_data_mux = VERSION_VALUE;
            REG_CAPABILITIES:   read_data_mux = CAPABILITIES;
            REG_STATUS:         read_data_mux = {29'b0, telemetry_fault,
                                                 telemetry_valid, 1'b1};
            REG_TEMP_MC:        read_data_mux = temperature_mc;
            REG_FAN_RPM:        read_data_mux = fan_rpm;
            REG_POWER0_RAW:     read_data_mux = {8'b0, input_power_snapshot};
            REG_POWER1_RAW:     read_data_mux = {8'b0, core_power_snapshot};
            REG_POWER0_LSB_NW:  read_data_mux = POWER_INPUT_LSB_NW;
            REG_POWER1_LSB_NW:  read_data_mux = POWER_CORE_LSB_NW;
            REG_SAMPLE_COUNT:   read_data_mux = snapshot_sequence;
            REG_TIMESTAMP_LO:   read_data_mux = snapshot_timestamp[31:0];
            REG_TIMESTAMP_HI:   read_data_mux = snapshot_timestamp[63:32];
            REG_TIMESTAMP_HZ:   read_data_mux = MGMT_CLK_HZ;
            REG_CLOCK_REQ_HZ:   read_data_mux = requested_hz;
            REG_CLOCK_CUR_HZ:   read_data_mux = current_hz;
            REG_CLOCK_COMMAND:  read_data_mux = 32'b0;
            REG_CLOCK_STATUS:   read_data_mux = clock_status;
            REG_CLOCK_REQ_SEQ:  read_data_mux = request_sequence;
            REG_CLOCK_DONE_SEQ: read_data_mux = clock_done_sequence;
            REG_QUIESCE_STATUS: read_data_mux = quiesce_status;
            REG_CLOCK_ERROR:    read_data_mux = clock_error_code;
            REG_CLOCK_MEASURED: read_data_mux = measured_hz;
            REG_FAN_STATUS:     read_data_mux = {16'b0, fan_dac, 5'b0,
                                                 fan_full_off,
                                                 fan_state_valid, fan_full_on};
            REG_FAN_CONTROL:    read_data_mux = {16'b0, fan_control_dac,
                                                 6'b0, fan_control_mode};
            default:            read_data_mux = 32'b0;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            avs_readdata <= 32'b0;
            avs_readdatavalid <= 1'b0;
            timestamp_counter <= 64'b0;
            snapshot_timestamp <= 64'b0;
            requested_hz <= 32'd250000000;
            request_sequence <= 32'b0;
            clock_apply <= 1'b0;
            clock_clear_status <= 1'b0;
            fan_control_mode <= 2'd0;
            fan_control_dac <= 8'h20;
            pll_locked_sync <= 2'b0;
            change_ack_sync <= 2'b0;
            memory_drain_ack_sync <= 2'b0;
        end else begin
            timestamp_counter <= timestamp_counter + 1'b1;
            pll_locked_sync <= {pll_locked_sync[0], pll_locked};
            change_ack_sync <= {change_ack_sync[0], clock_change_ack};
            memory_drain_ack_sync <= {memory_drain_ack_sync[0],
                                      memory_drain_ack};
            avs_readdatavalid <= avs_chipselect && avs_read;
            clock_apply <= 1'b0;
            clock_clear_status <= 1'b0;

            if (snapshot_update) begin
                snapshot_timestamp <= timestamp_counter;
            end

            if (avs_chipselect && avs_read) begin
                avs_readdata <= read_data_mux;
            end

            if (avs_chipselect && avs_write) begin
                if (avs_address == REG_CLOCK_REQ_HZ) begin
                    if (avs_byteenable[0]) requested_hz[7:0] <= avs_writedata[7:0];
                    if (avs_byteenable[1]) requested_hz[15:8] <= avs_writedata[15:8];
                    if (avs_byteenable[2]) requested_hz[23:16] <= avs_writedata[23:16];
                    if (avs_byteenable[3]) requested_hz[31:24] <= avs_writedata[31:24];
                end
                if (avs_address == REG_CLOCK_REQ_SEQ) begin
                    if (avs_byteenable[0]) request_sequence[7:0] <= avs_writedata[7:0];
                    if (avs_byteenable[1]) request_sequence[15:8] <= avs_writedata[15:8];
                    if (avs_byteenable[2]) request_sequence[23:16] <= avs_writedata[23:16];
                    if (avs_byteenable[3]) request_sequence[31:24] <= avs_writedata[31:24];
                end
                if ((avs_address == REG_CLOCK_COMMAND) && avs_byteenable[0]) begin
                    clock_apply <= avs_writedata[0];
                    clock_clear_status <= avs_writedata[1];
                end
                if (avs_address == REG_FAN_CONTROL) begin
                    if (avs_byteenable[0]) begin
                        fan_control_mode <= avs_writedata[1:0];
                    end
                    if (avs_byteenable[1]) begin
                        fan_control_dac <= avs_writedata[15:8];
                    end
                end
            end
        end
    end

    wire unused_raw_outputs = ^{tach1_snapshot, current_profile, clock_state,
                                raw_readdata, raw_readdatavalid,
                                raw_waitrequest};

endmodule
