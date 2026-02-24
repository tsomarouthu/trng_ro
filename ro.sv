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
// File: ro.sv
// -----------------------------------------------------------------------------

module ro #(
    parameter int STAGES = 11   // must be odd
)(
    input  logic ro_en,
    input  logic clk,
    output logic ro_out
);

   logic sync1;

	// -----------------------------------------------------------
   // SYNTHESIZABLE RO SV RTL
   // ------------------------------------------------------------
	(* keep = 1, dont_merge, noprune *) logic [STAGES-1:0] r;

   // Power‑gated ring oscillator starts with an enabler gate
   nand n_head (r[0], r[STAGES-1], ro_en);

   genvar i;
   generate
       for (i = 0; i < STAGES-1; i++) begin : gen_inv
			(* keep = 1, dont_merge *) not n_inv (r[i+1], r[i]);
       end
   endgenerate


    // Sampler
    always_ff @(posedge clk) begin
        sync1 <= r[STAGES-1];     // hardware path
    end

	 // Ouput from RO
    assign ro_out = sync1;


endmodule