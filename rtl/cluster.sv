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
// File: cluster.sv
// -----------------------------------------------------------------------------

module cluster #(
    parameter int NUM_RO     = 32,   // number of ring oscillators
    parameter int RO_STAGES  = 11    // must be odd; passed to each RO instance
)(
    input  logic ro_en,
    input  logic clk,
    output logic cluster_out
);

    // Array of RO outputs
    (* keep = "true" *) logic [NUM_RO-1:0] ro;

    // Generate NUM_RO instances of the parameterized RO
    genvar i;
    generate
        for (i = 0; i < NUM_RO; i++) begin : gen_ro
            ro #(
                .STAGES(RO_STAGES)
            ) U (
                .ro_en (ro_en),
                .clk   (clk),
                .ro_out(ro[i])
            );
        end
    endgenerate

    // XOR reduction of all RO outputs
    assign cluster_out = ^ro;
	 
endmodule