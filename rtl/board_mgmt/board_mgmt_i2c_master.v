`timescale 1ns/1ps

module board_mgmt_i2c_master #(
    parameter CLK_FREQ_HZ    = 50000000,
    parameter I2C_FREQ_HZ    = 100000,
    parameter TIMEOUT_CYCLES = 2500000
) (
    input  wire        clk,
    input  wire        reset,

    input  wire        cmd_valid,
    output wire        cmd_ready,
    input  wire        cmd_read,
    input  wire [6:0]  cmd_device_address,
    input  wire [7:0]  cmd_register_address,
    input  wire [7:0]  cmd_write_data,
    input  wire [2:0]  cmd_read_length,

    output reg         busy,
    output reg         done,
    output reg  [31:0] read_data,
    output reg  [2:0]  read_count,
    output reg         error_nack,
    output reg         error_timeout,
    output reg         error_bus_stuck,
    output reg         recovery_performed,

    input  wire        scl_i,
    input  wire        sda_i,
    output reg         scl_drive_low,
    output reg         sda_drive_low
);

    localparam integer RAW_TICK_DIVISOR = CLK_FREQ_HZ / (I2C_FREQ_HZ * 2);
    localparam integer TICK_DIVISOR = (RAW_TICK_DIVISOR < 1) ? 1 : RAW_TICK_DIVISOR;
    localparam integer TICK_COUNTER_WIDTH =
        (TICK_DIVISOR <= 1) ? 1 : $clog2(TICK_DIVISOR);

    localparam [4:0] STATE_IDLE                 = 5'd0;
    localparam [4:0] STATE_START_SETUP          = 5'd1;
    localparam [4:0] STATE_START_HOLD           = 5'd2;
    localparam [4:0] STATE_WRITE_LOW            = 5'd3;
    localparam [4:0] STATE_WRITE_HIGH           = 5'd4;
    localparam [4:0] STATE_ACK_LOW              = 5'd5;
    localparam [4:0] STATE_ACK_HIGH             = 5'd6;
    localparam [4:0] STATE_RESTART_LOW           = 5'd7;
    localparam [4:0] STATE_RESTART_HIGH          = 5'd8;
    localparam [4:0] STATE_RESTART_HOLD          = 5'd9;
    localparam [4:0] STATE_READ_LOW             = 5'd10;
    localparam [4:0] STATE_READ_HIGH            = 5'd11;
    localparam [4:0] STATE_READ_ACK_LOW          = 5'd12;
    localparam [4:0] STATE_READ_ACK_HIGH         = 5'd13;
    localparam [4:0] STATE_STOP_PREP             = 5'd14;
    localparam [4:0] STATE_STOP_LOW              = 5'd15;
    localparam [4:0] STATE_STOP_HIGH             = 5'd16;
    localparam [4:0] STATE_STOP_RELEASE          = 5'd17;
    localparam [4:0] STATE_RECOVER_LOW           = 5'd18;
    localparam [4:0] STATE_RECOVER_HIGH          = 5'd19;
    localparam [4:0] STATE_RECOVER_STOP_PREP     = 5'd20;
    localparam [4:0] STATE_RECOVER_STOP_LOW      = 5'd21;
    localparam [4:0] STATE_RECOVER_STOP_HIGH     = 5'd22;
    localparam [4:0] STATE_RECOVER_STOP_RELEASE  = 5'd23;

    localparam [1:0] BYTE_ADDRESS_WRITE = 2'd0;
    localparam [1:0] BYTE_REGISTER      = 2'd1;
    localparam [1:0] BYTE_DATA          = 2'd2;
    localparam [1:0] BYTE_ADDRESS_READ  = 2'd3;

    reg [4:0] state;
    reg [1:0] byte_kind;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [2:0] bit_index;
    reg [3:0] recovery_pulse_count;
    reg command_read;
    reg [6:0] device_address;
    reg [7:0] register_address;
    reg [7:0] write_data;
    reg [2:0] read_length;
    reg [TICK_COUNTER_WIDTH-1:0] tick_counter;
    reg [31:0] timeout_counter;
    reg waiting_for_scl_high;

    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] scl_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] sda_sync;

    wire clock_can_advance;
    wire phase_tick;

    assign cmd_ready = ~busy;
    assign clock_can_advance = ~waiting_for_scl_high | scl_sync[1];
    assign phase_tick = busy
                      && clock_can_advance
                      && (tick_counter == TICK_DIVISOR - 1);

    always @(*) begin
        waiting_for_scl_high = 1'b0;
        scl_drive_low = 1'b0;
        sda_drive_low = 1'b0;

        case (state)
            STATE_START_SETUP: begin
                waiting_for_scl_high = 1'b1;
            end
            STATE_START_HOLD: begin
                waiting_for_scl_high = 1'b1;
                sda_drive_low = 1'b1;
            end
            STATE_WRITE_LOW: begin
                scl_drive_low = 1'b1;
                sda_drive_low = ~tx_shift[7];
            end
            STATE_WRITE_HIGH: begin
                waiting_for_scl_high = 1'b1;
                sda_drive_low = ~tx_shift[7];
            end
            STATE_ACK_LOW: begin
                scl_drive_low = 1'b1;
            end
            STATE_ACK_HIGH: begin
                waiting_for_scl_high = 1'b1;
            end
            STATE_RESTART_LOW: begin
                scl_drive_low = 1'b1;
            end
            STATE_RESTART_HIGH: begin
                waiting_for_scl_high = 1'b1;
            end
            STATE_RESTART_HOLD: begin
                waiting_for_scl_high = 1'b1;
                sda_drive_low = 1'b1;
            end
            STATE_READ_LOW: begin
                scl_drive_low = 1'b1;
            end
            STATE_READ_HIGH: begin
                waiting_for_scl_high = 1'b1;
            end
            STATE_READ_ACK_LOW: begin
                scl_drive_low = 1'b1;
                sda_drive_low = (read_count + 1'b1 < read_length);
            end
            STATE_READ_ACK_HIGH: begin
                waiting_for_scl_high = 1'b1;
                sda_drive_low = (read_count + 1'b1 < read_length);
            end
            STATE_STOP_PREP: begin
                scl_drive_low = 1'b1;
            end
            STATE_STOP_LOW: begin
                scl_drive_low = 1'b1;
                sda_drive_low = 1'b1;
            end
            STATE_STOP_HIGH: begin
                waiting_for_scl_high = 1'b1;
                sda_drive_low = 1'b1;
            end
            STATE_STOP_RELEASE: begin
                waiting_for_scl_high = 1'b1;
            end
            STATE_RECOVER_LOW: begin
                scl_drive_low = 1'b1;
            end
            STATE_RECOVER_HIGH: begin
                waiting_for_scl_high = 1'b1;
            end
            STATE_RECOVER_STOP_PREP: begin
                scl_drive_low = 1'b1;
            end
            STATE_RECOVER_STOP_LOW: begin
                scl_drive_low = 1'b1;
                sda_drive_low = 1'b1;
            end
            STATE_RECOVER_STOP_HIGH: begin
                waiting_for_scl_high = 1'b1;
                sda_drive_low = 1'b1;
            end
            STATE_RECOVER_STOP_RELEASE: begin
                waiting_for_scl_high = 1'b1;
            end
            default: begin
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            scl_sync <= 2'b11;
            sda_sync <= 2'b11;
        end else begin
            scl_sync <= {scl_sync[0], scl_i};
            sda_sync <= {sda_sync[0], sda_i};
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            tick_counter <= {TICK_COUNTER_WIDTH{1'b0}};
        end else if (!busy || !clock_can_advance || phase_tick) begin
            tick_counter <= {TICK_COUNTER_WIDTH{1'b0}};
        end else begin
            tick_counter <= tick_counter + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            byte_kind <= BYTE_ADDRESS_WRITE;
            tx_shift <= 8'b0;
            rx_shift <= 8'b0;
            bit_index <= 3'b0;
            recovery_pulse_count <= 4'b0;
            command_read <= 1'b0;
            device_address <= 7'b0;
            register_address <= 8'b0;
            write_data <= 8'b0;
            read_length <= 3'd1;
            timeout_counter <= 32'b0;
            busy <= 1'b0;
            done <= 1'b0;
            read_data <= 32'b0;
            read_count <= 3'b0;
            error_nack <= 1'b0;
            error_timeout <= 1'b0;
            error_bus_stuck <= 1'b0;
            recovery_performed <= 1'b0;
        end else begin
            done <= 1'b0;

            if (cmd_valid && cmd_ready) begin
                device_address <= cmd_device_address;
                command_read <= cmd_read;
                register_address <= cmd_register_address;
                write_data <= cmd_write_data;
                if ((cmd_read_length == 0) || (cmd_read_length > 4)) begin
                    read_length <= 3'd1;
                end else begin
                    read_length <= cmd_read_length;
                end
                byte_kind <= BYTE_ADDRESS_WRITE;
                tx_shift <= {cmd_device_address, 1'b0};
                rx_shift <= 8'b0;
                bit_index <= 3'd7;
                recovery_pulse_count <= 4'b0;
                timeout_counter <= 32'b0;
                busy <= 1'b1;
                read_data <= 32'b0;
                read_count <= 3'b0;
                error_nack <= 1'b0;
                error_timeout <= 1'b0;
                error_bus_stuck <= 1'b0;
                recovery_performed <= 1'b0;
                if (scl_sync[1] && sda_sync[1]) begin
                    state <= STATE_START_SETUP;
                end else begin
                    state <= STATE_RECOVER_LOW;
                    recovery_performed <= 1'b1;
                end
            end else if (busy) begin
                if (waiting_for_scl_high && !scl_sync[1]) begin
                    if (timeout_counter + 1'b1 >= TIMEOUT_CYCLES) begin
                        state <= STATE_IDLE;
                        timeout_counter <= 32'b0;
                        busy <= 1'b0;
                        done <= 1'b1;
                        error_timeout <= 1'b1;
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                    end
                end else begin
                    timeout_counter <= 32'b0;
                    if (phase_tick) begin
                        case (state)
                            STATE_START_SETUP: begin
                                state <= STATE_START_HOLD;
                            end
                            STATE_START_HOLD: begin
                                state <= STATE_WRITE_LOW;
                            end
                            STATE_WRITE_LOW: begin
                                state <= STATE_WRITE_HIGH;
                            end
                            STATE_WRITE_HIGH: begin
                                if (bit_index == 0) begin
                                    state <= STATE_ACK_LOW;
                                end else begin
                                    tx_shift <= {tx_shift[6:0], 1'b0};
                                    bit_index <= bit_index - 1'b1;
                                    state <= STATE_WRITE_LOW;
                                end
                            end
                            STATE_ACK_LOW: begin
                                state <= STATE_ACK_HIGH;
                            end
                            STATE_ACK_HIGH: begin
                                if (sda_sync[1]) begin
                                    error_nack <= 1'b1;
                                    state <= STATE_STOP_PREP;
                                end else begin
                                    case (byte_kind)
                                        BYTE_ADDRESS_WRITE: begin
                                            byte_kind <= BYTE_REGISTER;
                                            tx_shift <= register_address;
                                            bit_index <= 3'd7;
                                            state <= STATE_WRITE_LOW;
                                        end
                                        BYTE_REGISTER: begin
                                            if (command_read) begin
                                                state <= STATE_RESTART_LOW;
                                            end else begin
                                                byte_kind <= BYTE_DATA;
                                                tx_shift <= write_data;
                                                bit_index <= 3'd7;
                                                state <= STATE_WRITE_LOW;
                                            end
                                        end
                                        BYTE_DATA: begin
                                            state <= STATE_STOP_PREP;
                                        end
                                        BYTE_ADDRESS_READ: begin
                                            rx_shift <= 8'b0;
                                            bit_index <= 3'd7;
                                            state <= STATE_READ_LOW;
                                        end
                                        default: begin
                                            error_nack <= 1'b1;
                                            state <= STATE_STOP_PREP;
                                        end
                                    endcase
                                end
                            end
                            STATE_RESTART_LOW: begin
                                state <= STATE_RESTART_HIGH;
                            end
                            STATE_RESTART_HIGH: begin
                                state <= STATE_RESTART_HOLD;
                            end
                            STATE_RESTART_HOLD: begin
                                byte_kind <= BYTE_ADDRESS_READ;
                                tx_shift <= {device_address, 1'b1};
                                bit_index <= 3'd7;
                                state <= STATE_WRITE_LOW;
                            end
                            STATE_READ_LOW: begin
                                state <= STATE_READ_HIGH;
                            end
                            STATE_READ_HIGH: begin
                                rx_shift <= {rx_shift[6:0], sda_sync[1]};
                                if (bit_index == 0) begin
                                    state <= STATE_READ_ACK_LOW;
                                end else begin
                                    bit_index <= bit_index - 1'b1;
                                    state <= STATE_READ_LOW;
                                end
                            end
                            STATE_READ_ACK_LOW: begin
                                state <= STATE_READ_ACK_HIGH;
                            end
                            STATE_READ_ACK_HIGH: begin
                                read_data <= {read_data[23:0], rx_shift};
                                read_count <= read_count + 1'b1;
                                if (read_count + 1'b1 >= read_length) begin
                                    state <= STATE_STOP_PREP;
                                end else begin
                                    rx_shift <= 8'b0;
                                    bit_index <= 3'd7;
                                    state <= STATE_READ_LOW;
                                end
                            end
                            STATE_STOP_PREP: begin
                                state <= STATE_STOP_LOW;
                            end
                            STATE_STOP_LOW: begin
                                state <= STATE_STOP_HIGH;
                            end
                            STATE_STOP_HIGH: begin
                                state <= STATE_STOP_RELEASE;
                            end
                            STATE_STOP_RELEASE: begin
                                if (!sda_sync[1]) begin
                                    error_bus_stuck <= 1'b1;
                                end
                                state <= STATE_IDLE;
                                busy <= 1'b0;
                                done <= 1'b1;
                            end
                            STATE_RECOVER_LOW: begin
                                state <= STATE_RECOVER_HIGH;
                            end
                            STATE_RECOVER_HIGH: begin
                                if (recovery_pulse_count == 8) begin
                                    state <= STATE_RECOVER_STOP_PREP;
                                end else begin
                                    recovery_pulse_count <= recovery_pulse_count + 1'b1;
                                    state <= STATE_RECOVER_LOW;
                                end
                            end
                            STATE_RECOVER_STOP_PREP: begin
                                state <= STATE_RECOVER_STOP_LOW;
                            end
                            STATE_RECOVER_STOP_LOW: begin
                                state <= STATE_RECOVER_STOP_HIGH;
                            end
                            STATE_RECOVER_STOP_HIGH: begin
                                state <= STATE_RECOVER_STOP_RELEASE;
                            end
                            STATE_RECOVER_STOP_RELEASE: begin
                                if (scl_sync[1] && sda_sync[1]) begin
                                    state <= STATE_START_SETUP;
                                end else begin
                                    state <= STATE_IDLE;
                                    busy <= 1'b0;
                                    done <= 1'b1;
                                    error_bus_stuck <= 1'b1;
                                end
                            end
                            default: begin
                                state <= STATE_IDLE;
                                busy <= 1'b0;
                                done <= 1'b1;
                                error_bus_stuck <= 1'b1;
                            end
                        endcase
                    end
                end
            end
        end
    end

endmodule
