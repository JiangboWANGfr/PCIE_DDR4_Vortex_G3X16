`timescale 1ns/1ps

module tb_i2c_slave_model #(
    parameter [6:0] DEVICE_ADDRESS = 7'h50
) (
    input  wire force_nack,
    inout  wire scl,
    inout  wire sda
);

    localparam [2:0] STATE_IDLE       = 3'd0;
    localparam [2:0] STATE_ADDRESS    = 3'd1;
    localparam [2:0] STATE_REGISTER   = 3'd2;
    localparam [2:0] STATE_WRITE_DATA = 3'd3;
    localparam [2:0] STATE_READ_DATA  = 3'd4;
    localparam [2:0] STATE_READ_ACK   = 3'd5;
    localparam [2:0] STATE_IGNORE     = 3'd6;

    reg [7:0] memory [0:255];
    reg [7:0] register_pointer;
    reg [7:0] shift_register;
    reg [2:0] bit_count;
    reg [2:0] state;
    reg [2:0] state_after_ack;
    reg [1:0] ack_phase;
    reg [1:0] read_ack_phase;
    reg selected;
    reg sda_drive_low;
    reg master_acknowledged;

    reg [7:0] last_write_register;
    reg [7:0] last_write_data;
    reg [7:0] first_write_register;
    reg [7:0] first_write_data;
    reg [7:0] write_register_log [0:31];
    reg [7:0] write_data_log [0:31];
    integer write_count;

    wire [7:0] received_byte;

    assign received_byte = {shift_register[6:0], sda};
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    initial begin
        register_pointer = 8'b0;
        shift_register = 8'b0;
        bit_count = 3'b0;
        state = STATE_IDLE;
        state_after_ack = STATE_IDLE;
        ack_phase = 2'b0;
        read_ack_phase = 2'b0;
        selected = 1'b0;
        sda_drive_low = 1'b0;
        master_acknowledged = 1'b0;
        last_write_register = 8'b0;
        last_write_data = 8'b0;
        first_write_register = 8'b0;
        first_write_data = 8'b0;
        write_count = 0;
    end

    always @(negedge sda) begin
        if (scl === 1'b1) begin
            shift_register <= 8'b0;
            bit_count <= 3'b0;
            state <= STATE_ADDRESS;
            state_after_ack <= STATE_IDLE;
            ack_phase <= 2'b0;
            read_ack_phase <= 2'b0;
            selected <= 1'b0;
            sda_drive_low <= 1'b0;
        end
    end

    always @(posedge sda) begin
        if (scl === 1'b1) begin
            state <= STATE_IDLE;
            ack_phase <= 2'b0;
            read_ack_phase <= 2'b0;
            selected <= 1'b0;
            sda_drive_low <= 1'b0;
        end
    end

    always @(posedge scl) begin
        if (ack_phase == 2'd2) begin
            ack_phase <= 2'd3;
        end else if (state == STATE_ADDRESS) begin
            shift_register <= received_byte;
            if (bit_count == 3'd7) begin
                bit_count <= 3'b0;
                selected <= (shift_register[6:0] == DEVICE_ADDRESS);
                ack_phase <= 2'd1;
                if (sda) begin
                    state_after_ack <= STATE_READ_DATA;
                end else begin
                    state_after_ack <= STATE_REGISTER;
                end
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end else if (state == STATE_REGISTER) begin
            shift_register <= received_byte;
            if (bit_count == 3'd7) begin
                bit_count <= 3'b0;
                register_pointer <= received_byte;
                ack_phase <= 2'd1;
                state_after_ack <= STATE_WRITE_DATA;
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end else if (state == STATE_WRITE_DATA) begin
            shift_register <= received_byte;
            if (bit_count == 3'd7) begin
                bit_count <= 3'b0;
                if (selected && !force_nack) begin
                    memory[register_pointer] <= received_byte;
                    if (write_count == 0) begin
                        first_write_register <= register_pointer;
                        first_write_data <= received_byte;
                    end
                    if (write_count < 32) begin
                        write_register_log[write_count] <= register_pointer;
                        write_data_log[write_count] <= received_byte;
                    end
                    last_write_register <= register_pointer;
                    last_write_data <= received_byte;
                    write_count <= write_count + 1;
                    register_pointer <= register_pointer + 1'b1;
                end
                ack_phase <= 2'd1;
                state_after_ack <= STATE_WRITE_DATA;
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end else if (state == STATE_READ_DATA) begin
            if (bit_count == 3'd7) begin
                bit_count <= 3'b0;
                read_ack_phase <= 2'b0;
                state <= STATE_READ_ACK;
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end else if ((state == STATE_READ_ACK) && (read_ack_phase == 2'd1)) begin
            master_acknowledged <= ~sda;
            read_ack_phase <= 2'd2;
        end
    end

    always @(negedge scl) begin
        if (ack_phase == 2'd1) begin
            sda_drive_low <= selected && !force_nack;
            ack_phase <= 2'd2;
        end else if (ack_phase == 2'd3) begin
            ack_phase <= 2'd0;
            sda_drive_low <= 1'b0;
            if (selected && !force_nack) begin
                state <= state_after_ack;
                if (state_after_ack == STATE_READ_DATA) begin
                    sda_drive_low <= ~memory[register_pointer][7];
                end
            end else begin
                state <= STATE_IGNORE;
            end
        end else if (state == STATE_READ_DATA) begin
            sda_drive_low <= ~memory[register_pointer][7 - bit_count];
        end else if (state == STATE_READ_ACK) begin
            if (read_ack_phase == 2'd0) begin
                sda_drive_low <= 1'b0;
                read_ack_phase <= 2'd1;
            end else if (read_ack_phase == 2'd2) begin
                read_ack_phase <= 2'd0;
                if (master_acknowledged) begin
                    register_pointer <= register_pointer + 1'b1;
                    state <= STATE_READ_DATA;
                    sda_drive_low <= ~memory[register_pointer + 1'b1][7];
                end else begin
                    state <= STATE_IGNORE;
                    sda_drive_low <= 1'b0;
                end
            end else begin
                sda_drive_low <= 1'b0;
            end
        end else begin
            sda_drive_low <= 1'b0;
        end
    end

endmodule
