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
// File: uart_tx.sv
// -----------------------------------------------------------------------------

// Simple UART Transmitter with Parity Support
module uart_tx #(
    parameter CLK_FREQ    = 50_000_000, // 50 MHz
    parameter BAUD_RATE   = 115200,
    parameter PARITY_TYPE = "EVEN"    // "NONE", "EVEN", or "ODD"
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] data_in,   // Data to transmit
    input  logic       tx_start,  // Pulse to start transmission (for a new byte)
    output logic       uart_tx,   // UART transmit pin
    output logic       tx_busy    // High while transmitting
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    // Determine number of data bits + parity bit
    localparam NUM_DATA_BITS = 8;
    localparam HAS_PARITY = (PARITY_TYPE == "EVEN" || PARITY_TYPE == "ODD");
    localparam TOTAL_TX_BITS = NUM_DATA_BITS + HAS_PARITY; // 8 or 9 bits for data/parity

    typedef enum logic [2:0] {
        S_IDLE,
        S_START_BIT,
        S_DATA_BITS,
        S_PARITY_BIT, // New state for parity
        S_STOP_BIT
    } state_t;

    state_t state, next_state;
    logic [7:0] data_reg;
    logic [$clog2(BAUD_DIV)-1:0] clk_count;
    logic [$clog2(NUM_DATA_BITS)-1:0] bit_count; // Counts from 0 to NUM_DATA_BITS-1

    logic parity_bit;

    // Calculate Parity Bit
    always_comb begin
        case (PARITY_TYPE)
            "EVEN": parity_bit = ^data_reg; // XOR sum of data_reg
            "ODD":  parity_bit = !(^data_reg); // Inverse of XOR sum
            default: parity_bit = 1'b0; // Not used, default to 0 for synthesis
        endcase
    end

    // State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // Combinational Logic for Next State and Outputs
    always_comb begin
        next_state = state;
        uart_tx = 1'b1; // Idle is high
        tx_busy = (state != S_IDLE);

        case (state)
            S_IDLE: begin
                if (tx_start) begin
                    next_state = S_START_BIT;
                end
            end
            S_START_BIT: begin
                uart_tx = 1'b0; // Start bit is always low
                if (clk_count == BAUD_DIV - 1) begin
                    next_state = S_DATA_BITS;
                end
            end
            S_DATA_BITS: begin
                uart_tx = data_reg[bit_count]; // Transmit current data bit
                if (clk_count == BAUD_DIV - 1) begin
                    if (bit_count == NUM_DATA_BITS - 1) begin
                        if (HAS_PARITY) begin
                            next_state = S_PARITY_BIT; // Go to parity if enabled
                        end else begin
                            next_state = S_STOP_BIT;   // Skip parity if not enabled
                        end
                    end else begin
                        next_state = S_DATA_BITS; // Stay in this state
                    end
                end
            end
            S_PARITY_BIT: begin // New state for transmitting the parity bit
                uart_tx = parity_bit;
                if (clk_count == BAUD_DIV - 1) begin
                    next_state = S_STOP_BIT;
                end
            end
            S_STOP_BIT: begin
                uart_tx = 1'b1; // Stop bit is always high
                if (clk_count == BAUD_DIV - 1) begin
                    next_state = S_IDLE;
                end
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Counters and Data Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_count <= '0;
            bit_count <= '0;
            data_reg  <= '0;
        end else begin
            if (state == S_IDLE) begin
                clk_count <= '0;
                bit_count <= '0;
                if (tx_start) begin
                    data_reg <= data_in; // Latch input data
                end
            end else begin
                // Increment clk_count on every clock cycle in a transmit state
                if (clk_count == BAUD_DIV - 1) begin
                    clk_count <= '0; // Reset for next bit period

                    // Increment bit_count only when transmitting data bits
                    if (state == S_DATA_BITS) begin
                        bit_count <= bit_count + 1;
                    end
                end else begin
                    clk_count <= clk_count + 1;
                end
            end
        end
    end

endmodule