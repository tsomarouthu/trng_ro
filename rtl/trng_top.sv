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
// File: trng_top.sv
// -----------------------------------------------------------------------------

module trng_top #(
    parameter int CLK_FREQ   = 50_000_000,  // Hz
    parameter int BAUD_RATE  = 115200,      // bps
    parameter string PARITY  = "EVEN"       // "NONE", "EVEN", "ODD"
)(
      ///////// CLOCK /////////
      input              CLOCK_50, ///2.5 V

      ///////// KEY ///////// 1.2 V ///////
      input       [0:0]  KEY,

      ///////// LED ///////// 2.5 V ///////
      output      [1:0]  LED,

      ///////// SW ///////// 1.2 V ///////
      input       [1:0]  SW,

      ///////// UART ///////// 2.5 V ///////
      input              UART_RX,
      output             UART_TX
);

    // ------------------------------------------------------------
    // Reset and switches
    // ------------------------------------------------------------
    wire rst_n = KEY[0];
    wire ro_en = SW[0];
    wire start = SW[1];

    logic ro_en_dbnc, start_dbnc;

`ifndef SYNTHESIS
    assign ro_en_dbnc = ro_en;
    assign start_dbnc = start;
`else
    switch_debouncer dbnc_u0 (
        .clk        (CLOCK_50),
        .rst_n      (rst_n),
        .switch_in  (ro_en),
        .switch_out (ro_en_dbnc)
    );

    switch_debouncer dbnc_u1 (
        .clk        (CLOCK_50),
        .rst_n      (rst_n),
        .switch_in  (start),
        .switch_out (start_dbnc)
    );
`endif

    // ------------------------------------------------------------
    // TRNG core
    // ------------------------------------------------------------
    logic trng_raw;

    trng_core #(
        .NUM_SRC   (4),
        .NUM_RO    (32),
        .RO_STAGES (11)
    ) trng_core_inst (
        .clk      (CLOCK_50),
        .rst_n    (rst_n),
        .start    (start_dbnc),
        .ro_en    (ro_en_dbnc),
        .trng_out (trng_raw)
    );

    // ------------------------------------------------------------
    // TRNG Streamer (Sampler → Byte Assembler → FIFO → UART)
    // ------------------------------------------------------------
    trng_streamer #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .PARITY    ("EVEN")
    ) streamer_inst (
        .clk        (CLOCK_50),
        .rst_n      (rst_n),

        .trng_raw   (trng_raw),
        .start      (start_dbnc),

        .uart_tx    (UART_TX)
    );

    // ------------------------------------------------------------
    // LED blinker
    // ------------------------------------------------------------
    logic [25:0] counter;
    logic        led_level;

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            counter    <= 26'd0;
            led_level  <= 1'b0;
        end
        else if (counter == 26'd24_999_999) begin
            counter    <= 26'd0;
            led_level  <= ~led_level;
        end
        else begin
            counter <= counter + 1'b1;
        end
    end

    assign LED[0] = led_level;
    assign LED[1] = led_level & ro_en_dbnc & start_dbnc;

endmodule