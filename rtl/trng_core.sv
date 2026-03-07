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
// File: trng_core.sv
// -----------------------------------------------------------------------------

module trng_core #(
    parameter int NUM_SRC    = 4,     // number of fr_high entropy sources
    parameter int NUM_RO     = 32,    // updated to match your "Golden" config
    parameter int RO_STAGES  = 11     // updated to match your "Golden" config
)(
    input  logic clk,
    input  logic rst_n,
    input  logic ro_en,
    input  logic start,
    output logic trng_out
);

`ifndef SYNTHESIS

  // Icarus-friendly constant function instead of param array
  function automatic int inv_cnt(input int i);
    case (i)
      0: inv_cnt = 11;
      1: inv_cnt = 13;
      2: inv_cnt = 17;
      3: inv_cnt = 19;
      default: inv_cnt = 11;
    endcase
  endfunction

`else

	 localparam int INV_CNT[NUM_SRC] = '{	
                                        11,
                                        13,
                                        17,
                                        19
                                    };


`endif

	logic [NUM_SRC-1:0] cluster_o;
	logic mixed_entropy;


	// Generate NUM_SRC instances of fr_high
	genvar i;
	generate
		for (i = 0; i < NUM_SRC; i++) begin : gen_cluster
			localparam int STAGES_THIS = inv_cnt(i);
			cluster #(
				.NUM_RO(NUM_RO),
`ifndef SYNTHESIS
				.RO_STAGES(STAGES_THIS)
`else
				.RO_STAGES(INV_CNT[i])
`endif
				) u_cluster (
					.ro_en (ro_en),
					.clk   (clk),
					.cluster_out  (cluster_o[i])
			);
		end
	endgenerate

	assign mixed_entropy = ^cluster_o;

	logic sync1_cdc, sync2_cdc; // 2-stage synchronizer

	always_ff @(posedge clk or negedge rst_n) begin
	  if (!rst_n) begin
			sync1_cdc <= 1'b0;
			sync2_cdc <= 1'b0;
	  end else begin
			sync1_cdc <= mixed_entropy; // First stage, can go metastable
			sync2_cdc <= sync1_cdc;     // Second stage, highly likely to resolve
	  end
	end

	always_ff @(posedge clk or negedge rst_n)
		if (!rst_n) 		trng_out <= 1'b0;
		else if (start)	trng_out <= sync2_cdc;     // Third stage, guaranteed resolved
												
endmodule