// -----------------------------------------------------------------------------
// Copyright 2026 Trinath Somarouthu
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions
// and limitations under the License.
// -----------------------------------------------------------------------------
// File: trng_streamer.sv
// -----------------------------------------------------------------------------

module trng_streamer #(
    parameter int CLK_FREQ   = 50_000_000,  // Hz
    parameter int BAUD_RATE  = 115200,      // bps
    parameter string PARITY  = "EVEN"       // "NONE", "EVEN", "ODD"
)(
    input  logic clk,
    input  logic rst_n,

    // TRNG raw bit input
    input  logic trng_raw,
    input  logic start,        // enable sampling

    // FIFO status (optional external visibility)
    output logic fifo_empty,
    output logic fifo_full,

    // UART output
    output logic uart_tx
);

    // ------------------------------------------------------------
    // UART throughput math
    // ------------------------------------------------------------
	localparam int UART_BITS_PER_BYTE =
		 (PARITY == "NONE") ? 10 : 11;

	localparam int UART_BYTE_RATE = BAUD_RATE / UART_BITS_PER_BYTE;

	// SAFETY = 0.8 = 8/10
	localparam int NUM = CLK_FREQ * 10;          // scaled numerator
	localparam int DEN = 64 * UART_BYTE_RATE;    // 8 bits * 0.8 safety = 64/10

	// Synthesizable ceiling division
	localparam int SAMPLE_DIV_MIN = (NUM + DEN - 1) / DEN;
	localparam int SAMPLE_DIV     = (SAMPLE_DIV_MIN < 1) ? 1 : SAMPLE_DIV_MIN;
    // ------------------------------------------------------------
    // sample_pulse generator (one-clock-wide strobe)
    // ------------------------------------------------------------
    logic [$clog2(SAMPLE_DIV)-1:0] sample_cnt;
    logic sample_pulse;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt   <= '0;
            sample_pulse <= 1'b0;
        end else begin
            if (sample_cnt == SAMPLE_DIV-1) begin
                sample_cnt   <= '0;
                sample_pulse <= 1'b1;
            end else begin
                sample_cnt   <= sample_cnt + 1'b1;
                sample_pulse <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------
    // FIFO - 128 deep
    // ------------------------------------------------------------
    logic        fifo_wr;
    logic        fifo_rd;
    logic [7:0]  fifo_q;
    logic [7:0]  fifo_data_in;

    trng_fifo fifo_inst (
        .clock (clk),
        .data  (fifo_data_in),
        .wrreq (fifo_wr),
        .rdreq (fifo_rd),
        .empty (fifo_empty),
        .full  (fifo_full),
        .q     (fifo_q)
    );

    // ------------------------------------------------------------
    // Byte assembler
    // ------------------------------------------------------------
    logic [7:0] byte_buffer;
    logic [2:0] bit_counter;
    logic       byte_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= 3'd0;
            byte_buffer <= 8'd0;
            byte_ready  <= 1'b0;
        end else begin
            byte_ready <= 1'b0;

            if (start && !fifo_full && sample_pulse) begin
                byte_buffer <= {trng_raw, byte_buffer[7:1]};

                if (bit_counter == 3'd7) begin
                    bit_counter <= 3'd0;
                    byte_ready  <= 1'b1;
                end else begin
                    bit_counter <= bit_counter + 3'd1;
                end
            end
        end
    end

    assign fifo_data_in = byte_buffer;
    assign fifo_wr      = byte_ready;

    // ------------------------------------------------------------
    // UART feeder
    // ------------------------------------------------------------
    logic uart_tx_start;
    logic uart_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx_start <= 1'b0;
            fifo_rd       <= 1'b0;
        end else begin
            uart_tx_start <= 1'b0;
            fifo_rd       <= 1'b0;

            if (!uart_busy && !fifo_empty) begin
                fifo_rd       <= 1'b1;
                uart_tx_start <= 1'b1;
            end
        end
    end

    uart_tx #(
        .CLK_FREQ    (CLK_FREQ),
        .BAUD_RATE   (BAUD_RATE),
        .PARITY_TYPE (PARITY)
    ) uart_tx_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (fifo_q),
        .tx_start (uart_tx_start),
        .uart_tx  (uart_tx),
        .tx_busy  (uart_busy)
    );

endmodule