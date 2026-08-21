`timescale 1ns/1ps

module de10pro_dynamic_clock #(
    parameter MGMT_CLK_HZ = 50000000,
    parameter MEASURE_WINDOW_CYCLES = 5000000,
    parameter QUIESCE_GUARD_CYCLES = 50000,
    parameter QUIESCE_TIMEOUT_CYCLES = 50000000,
    parameter RECONFIG_TIMEOUT_CYCLES = 50000000,
    parameter LOCK_STABLE_CYCLES = 16
) (
    input  wire        mgmt_clk,
    input  wire        reset,

    input  wire        apply,
    input  wire        clear_status,
    input  wire [31:0] requested_hz,
    input  wire [31:0] request_sequence,

    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [31:0] error_code,
    output reg  [31:0] current_hz,
    output reg         current_valid,
    output reg  [31:0] done_sequence,
    output reg  [1:0]  current_profile,
    output reg  [3:0]  state,

    output reg         clock_change_req,
    output reg         clock_reset_req,
    input  wire        clock_change_ack,
    input  wire        memory_drain_ack,
    input  wire        clock_reset_ack,

    input  wire        pll_locked,
    input  wire        vortex_clk,
    output reg  [31:0] measured_hz,

    output wire [9:0]  reconfig_address,
    output wire        reconfig_read,
    output wire        reconfig_write,
    output wire [7:0]  reconfig_writedata,
    input  wire [7:0]  reconfig_readdata,
    input  wire        reconfig_waitrequest
);

    localparam [3:0] STATE_STARTUP       = 4'd0;
    localparam [3:0] STATE_IDLE          = 4'd1;
    localparam [3:0] STATE_QUIESCE       = 4'd2;
    localparam [3:0] STATE_DRAIN_GUARD   = 4'd3;
    localparam [3:0] STATE_ASSERT_RESET  = 4'd4;
    localparam [3:0] STATE_RECONFIGURE   = 4'd5;
    localparam [3:0] STATE_WAIT_LOCK     = 4'd6;
    localparam [3:0] STATE_RELEASE_RESET = 4'd7;
    localparam [3:0] STATE_ERROR_HOLD    = 4'd8;

    localparam [31:0] ERROR_NONE             = 32'd0;
    localparam [31:0] ERROR_BAD_FREQUENCY    = 32'd1;
    localparam [31:0] ERROR_QUIESCE_TIMEOUT  = 32'd3;
    localparam [31:0] ERROR_RECONFIG_TIMEOUT = 32'd4;
    localparam [31:0] ERROR_PLL_UNLOCKED     = 32'd5;
    localparam [31:0] ERROR_INTERNAL         = 32'd6;

    localparam integer MEASURE_SCALE = MGMT_CLK_HZ / MEASURE_WINDOW_CYCLES;

    reg [31:0] timeout_counter;
    reg [31:0] quiesce_guard_counter;
    reg [31:0] lock_stable_counter;
    reg [1:0] pending_profile;
    reg [31:0] pending_hz;
    reg [31:0] pending_sequence;

    reg [31:0] vortex_counter;
    (* preserve, dont_merge *) reg [31:0] vortex_counter_gray;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] vortex_reset_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [31:0] vortex_gray_meta;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [31:0] vortex_gray_sync;
    reg [31:0] vortex_sample;
    reg [31:0] measure_counter;

    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] pll_locked_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] change_ack_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] memory_drain_ack_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] reset_ack_sync;

    wire [2:0] requested_profile;
    wire [31:0] vortex_counter_binary;
    wire [31:0] measurement_delta;
    wire [63:0] measurement_scaled;

    function [2:0] decode_profile;
        input [31:0] frequency_hz;
        begin
            case (frequency_hz)
                32'd100000000: decode_profile = {1'b1, 2'd0};
                32'd125000000: decode_profile = {1'b1, 2'd1};
                32'd200000000: decode_profile = {1'b1, 2'd2};
                32'd250000000: decode_profile = {1'b1, 2'd3};
                default:       decode_profile = 3'b000;
            endcase
        end
    endfunction

    function [31:0] gray_to_binary;
        input [31:0] gray;
        integer bit_index;
        begin
            gray_to_binary[31] = gray[31];
            for (bit_index = 30; bit_index >= 0; bit_index = bit_index - 1) begin
                gray_to_binary[bit_index] = gray_to_binary[bit_index + 1]
                                          ^ gray[bit_index];
            end
        end
    endfunction

    assign requested_profile = decode_profile(requested_hz);
    assign reconfig_address = 10'b0;
    assign reconfig_read = 1'b0;
    assign reconfig_write = (state == STATE_RECONFIGURE)
                          && change_ack_sync[1]
                          && memory_drain_ack_sync[1]
                          && reset_ack_sync[1];
    assign reconfig_writedata = {6'b0, pending_profile};
    assign vortex_counter_binary = gray_to_binary(vortex_gray_sync);
    assign measurement_delta = vortex_counter_binary - vortex_sample;
    assign measurement_scaled = measurement_delta * MEASURE_SCALE;

    wire unused_reconfig_readdata = ^reconfig_readdata;

    initial begin
        if ((MEASURE_WINDOW_CYCLES < 1)
         || ((MGMT_CLK_HZ % MEASURE_WINDOW_CYCLES) != 0)) begin
            $error("MEASURE_WINDOW_CYCLES must divide MGMT_CLK_HZ");
        end
    end

    always @(posedge vortex_clk or posedge reset) begin
        if (reset) begin
            vortex_reset_sync <= 2'b11;
        end else begin
            vortex_reset_sync <= {vortex_reset_sync[0], 1'b0};
        end
    end

    always @(posedge vortex_clk or posedge vortex_reset_sync[1]) begin
        if (vortex_reset_sync[1]) begin
            vortex_counter <= 32'b0;
            vortex_counter_gray <= 32'b0;
        end else begin
            vortex_counter <= vortex_counter + 1'b1;
            vortex_counter_gray <= (vortex_counter + 1'b1)
                                 ^ ((vortex_counter + 1'b1) >> 1);
        end
    end

    always @(posedge mgmt_clk) begin
        if (reset) begin
            vortex_gray_meta <= 32'b0;
            vortex_gray_sync <= 32'b0;
            vortex_sample <= 32'b0;
            measure_counter <= 32'b0;
            measured_hz <= 32'b0;
        end else begin
            vortex_gray_meta <= vortex_counter_gray;
            vortex_gray_sync <= vortex_gray_meta;

            if ((MEASURE_WINDOW_CYCLES <= 1)
             || (measure_counter + 1'b1 >= MEASURE_WINDOW_CYCLES)) begin
                measured_hz <= measurement_scaled[31:0];
                vortex_sample <= vortex_counter_binary;
                measure_counter <= 32'b0;
            end else begin
                measure_counter <= measure_counter + 1'b1;
            end
        end
    end

    always @(posedge mgmt_clk) begin
        if (reset) begin
            pll_locked_sync <= 2'b0;
            change_ack_sync <= 2'b0;
            memory_drain_ack_sync <= 2'b0;
            reset_ack_sync <= 2'b0;
        end else begin
            pll_locked_sync <= {pll_locked_sync[0], pll_locked};
            change_ack_sync <= {change_ack_sync[0], clock_change_ack};
            memory_drain_ack_sync <= {memory_drain_ack_sync[0],
                                      memory_drain_ack};
            reset_ack_sync <= {reset_ack_sync[0], clock_reset_ack};
        end
    end

    always @(posedge mgmt_clk) begin
        if (reset) begin
            busy <= 1'b1;
            done <= 1'b0;
            error <= 1'b0;
            error_code <= ERROR_NONE;
            // Startup never reconfigures the PLL, it only waits for lock, so
            // these are a claim about how the IOPLL was solved rather than a
            // program of it. They must match gui_output_clock_frequency0 in
            // integrate_vortex.tcl; nothing here can detect a disagreement.
            current_hz <= 32'd200000000;
            current_valid <= 1'b0;
            done_sequence <= 32'b0;
            current_profile <= 2'd2;
            pending_profile <= 2'd2;
            pending_hz <= 32'd200000000;
            pending_sequence <= 32'b0;
            state <= STATE_STARTUP;
            clock_change_req <= 1'b1;
            clock_reset_req <= 1'b1;
            timeout_counter <= 32'b0;
            quiesce_guard_counter <= 32'b0;
            lock_stable_counter <= 32'b0;
        end else begin
            if (clear_status && !busy) begin
                done <= 1'b0;
                error <= 1'b0;
                error_code <= ERROR_NONE;
            end

            case (state)
                STATE_STARTUP: begin
                    if (timeout_counter + 1'b1 >= RECONFIG_TIMEOUT_CYCLES) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_PLL_UNLOCKED;
                        current_valid <= 1'b0;
                        timeout_counter <= 32'b0;
                        lock_stable_counter <= 32'b0;
                        state <= STATE_ERROR_HOLD;
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                        if (pll_locked_sync[1]) begin
                            if ((LOCK_STABLE_CYCLES <= 1)
                             || (lock_stable_counter + 1'b1 >= LOCK_STABLE_CYCLES)) begin
                                busy <= 1'b0;
                                current_valid <= 1'b1;
                                clock_change_req <= 1'b0;
                                clock_reset_req <= 1'b0;
                                timeout_counter <= 32'b0;
                                lock_stable_counter <= 32'b0;
                                state <= STATE_IDLE;
                            end else begin
                                lock_stable_counter <= lock_stable_counter + 1'b1;
                            end
                        end else begin
                            lock_stable_counter <= 32'b0;
                        end
                    end
                end

                STATE_IDLE: begin
                    if (!pll_locked_sync[1]) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_PLL_UNLOCKED;
                        current_valid <= 1'b0;
                        clock_change_req <= 1'b1;
                        clock_reset_req <= 1'b1;
                        timeout_counter <= 32'b0;
                        quiesce_guard_counter <= 32'b0;
                        lock_stable_counter <= 32'b0;
                        if (apply) begin
                            done_sequence <= request_sequence;
                        end
                        state <= STATE_ERROR_HOLD;
                    end else if (apply) begin
                        done <= 1'b0;
                        error <= 1'b0;
                        error_code <= ERROR_NONE;
                        done_sequence <= request_sequence;
                        if (!requested_profile[2]) begin
                            done <= 1'b1;
                            error <= 1'b1;
                            error_code <= ERROR_BAD_FREQUENCY;
                        end else if ((requested_hz == current_hz) && current_valid) begin
                            done <= 1'b1;
                        end else begin
                            busy <= 1'b1;
                            pending_profile <= requested_profile[1:0];
                            pending_hz <= requested_hz;
                            pending_sequence <= request_sequence;
                            clock_change_req <= 1'b1;
                            timeout_counter <= 32'b0;
                            quiesce_guard_counter <= 32'b0;
                            state <= STATE_QUIESCE;
                        end
                    end
                end

                STATE_QUIESCE: begin
                    if (timeout_counter + 1'b1 >= QUIESCE_TIMEOUT_CYCLES) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_QUIESCE_TIMEOUT;
                        done_sequence <= pending_sequence;
                        timeout_counter <= 32'b0;
                        quiesce_guard_counter <= 32'b0;
                        if (clock_reset_req) begin
                            state <= STATE_ERROR_HOLD;
                        end else begin
                            clock_change_req <= 1'b0;
                            state <= STATE_IDLE;
                        end
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                        if (change_ack_sync[1]
                         && memory_drain_ack_sync[1]) begin
                            quiesce_guard_counter <= 32'b0;
                            state <= STATE_DRAIN_GUARD;
                        end
                    end
                end

                STATE_DRAIN_GUARD: begin
                    if (timeout_counter + 1'b1 >= QUIESCE_TIMEOUT_CYCLES) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_QUIESCE_TIMEOUT;
                        done_sequence <= pending_sequence;
                        timeout_counter <= 32'b0;
                        quiesce_guard_counter <= 32'b0;
                        if (clock_reset_req) begin
                            state <= STATE_ERROR_HOLD;
                        end else begin
                            clock_change_req <= 1'b0;
                            state <= STATE_IDLE;
                        end
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                        if (!change_ack_sync[1]
                         || !memory_drain_ack_sync[1]) begin
                            quiesce_guard_counter <= 32'b0;
                            state <= STATE_QUIESCE;
                        end else if ((QUIESCE_GUARD_CYCLES <= 1)
                                  || (quiesce_guard_counter + 1'b1
                                      >= QUIESCE_GUARD_CYCLES)) begin
                            clock_reset_req <= 1'b1;
                            timeout_counter <= 32'b0;
                            quiesce_guard_counter <= 32'b0;
                            state <= STATE_ASSERT_RESET;
                        end else begin
                            quiesce_guard_counter <= quiesce_guard_counter + 1'b1;
                        end
                    end
                end

                STATE_ASSERT_RESET: begin
                    if (change_ack_sync[1]
                     && memory_drain_ack_sync[1]
                     && reset_ack_sync[1]) begin
                        current_valid <= 1'b0;
                        timeout_counter <= 32'b0;
                        lock_stable_counter <= 32'b0;
                        state <= STATE_RECONFIGURE;
                    end else if (timeout_counter + 1'b1 >= QUIESCE_TIMEOUT_CYCLES) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_QUIESCE_TIMEOUT;
                        done_sequence <= pending_sequence;
                        timeout_counter <= 32'b0;
                        state <= STATE_ERROR_HOLD;
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                    end
                end

                STATE_RECONFIGURE: begin
                    if (!change_ack_sync[1]
                     || !memory_drain_ack_sync[1]
                     || !reset_ack_sync[1]) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_QUIESCE_TIMEOUT;
                        done_sequence <= pending_sequence;
                        timeout_counter <= 32'b0;
                        state <= STATE_ERROR_HOLD;
                    end else if (!reconfig_waitrequest) begin
                        timeout_counter <= 32'b0;
                        lock_stable_counter <= 32'b0;
                        state <= STATE_WAIT_LOCK;
                    end else if (timeout_counter + 1'b1 >= RECONFIG_TIMEOUT_CYCLES) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_RECONFIG_TIMEOUT;
                        done_sequence <= pending_sequence;
                        timeout_counter <= 32'b0;
                        state <= STATE_ERROR_HOLD;
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                    end
                end

                STATE_WAIT_LOCK: begin
                    if (timeout_counter + 1'b1 >= RECONFIG_TIMEOUT_CYCLES) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_PLL_UNLOCKED;
                        done_sequence <= pending_sequence;
                        timeout_counter <= 32'b0;
                        state <= STATE_ERROR_HOLD;
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                        if (!reconfig_waitrequest && pll_locked_sync[1]) begin
                            if ((LOCK_STABLE_CYCLES <= 1)
                             || (lock_stable_counter + 1'b1
                                 >= LOCK_STABLE_CYCLES)) begin
                                current_hz <= pending_hz;
                                current_profile <= pending_profile;
                                current_valid <= 1'b1;
                                clock_reset_req <= 1'b0;
                                timeout_counter <= 32'b0;
                                lock_stable_counter <= 32'b0;
                                state <= STATE_RELEASE_RESET;
                            end else begin
                                lock_stable_counter <= lock_stable_counter + 1'b1;
                            end
                        end else begin
                            lock_stable_counter <= 32'b0;
                        end
                    end
                end

                STATE_RELEASE_RESET: begin
                    if (!reset_ack_sync[1]) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b0;
                        error_code <= ERROR_NONE;
                        done_sequence <= pending_sequence;
                        clock_change_req <= 1'b0;
                        state <= STATE_IDLE;
                    end else if (timeout_counter + 1'b1 >= QUIESCE_TIMEOUT_CYCLES) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERROR_INTERNAL;
                        done_sequence <= pending_sequence;
                        clock_reset_req <= 1'b1;
                        timeout_counter <= 32'b0;
                        state <= STATE_ERROR_HOLD;
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                    end
                end

                STATE_ERROR_HOLD: begin
                    if (apply && requested_profile[2]) begin
                        busy <= 1'b1;
                        done <= 1'b0;
                        error <= 1'b0;
                        error_code <= ERROR_NONE;
                        pending_profile <= requested_profile[1:0];
                        pending_hz <= requested_hz;
                        pending_sequence <= request_sequence;
                        timeout_counter <= 32'b0;
                        quiesce_guard_counter <= 32'b0;
                        lock_stable_counter <= 32'b0;
                        state <= STATE_QUIESCE;
                    end
                end

                default: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    error <= 1'b1;
                    error_code <= ERROR_INTERNAL;
                    current_valid <= 1'b0;
                    clock_change_req <= 1'b1;
                    clock_reset_req <= 1'b1;
                    state <= STATE_ERROR_HOLD;
                end
            endcase
        end
    end

endmodule
