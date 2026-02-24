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
// File: switch_debouncer.sv
// -----------------------------------------------------------------------------

module switch_debouncer #(
    parameter DEBOUNCE_TIME_MS = 20,  // 20ms debounce
    parameter CLK_FREQ_MHZ = 50       // 50MHz clock
)(
    input  logic clk,
    input  logic rst_n,
    input  logic switch_in,
    output logic switch_out
);

    localparam int COUNT_MAX = CLK_FREQ_MHZ * 1000 * DEBOUNCE_TIME_MS;
    
    logic [1:0] sync_reg;
    logic [$clog2(COUNT_MAX)-1:0] counter;
    logic switch_stable;
    
    // Two-stage synchronizer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync_reg <= 2'b0;
        else
            sync_reg <= {sync_reg[0], switch_in};
    end
    
    // Debounce counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= '0;
            switch_stable <= 1'b0;
        end else begin
            if (sync_reg[1] != switch_stable) begin
                if (counter == COUNT_MAX - 1) begin
                    switch_stable <= sync_reg[1];
                    counter <= '0;
                end else begin
                    counter <= counter + 1'b1;
                end
            end else begin
                counter <= '0;
            end
        end
    end
    
    assign switch_out = switch_stable;
    
endmodule