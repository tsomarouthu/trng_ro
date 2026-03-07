module trng_streamer #(
    parameter int CLK_FREQ   = 50_000_000,   // Hz
    parameter int SAMPLE_US  = 12,           // choose 10/12/15
    parameter int BAUD_RATE  = 115200,
    parameter string PARITY  = "EVEN"
)(
    input  logic clk,
    input  logic rst_n,

    input  logic trng_raw,
    input  logic start,          // enable sampling

    output logic uart_tx
);

    //------------------------------------------------------------
    // 1) Sample timer (one strobe every SAMPLE_US microseconds)
    //------------------------------------------------------------
    // Integer ceiling division helper
    `define CEIL_DIV(N, D)  (((N) + (D) - 1) / (D))

    // Compute SAMPLE_DIV from CLK (Hz), BAUD (bps), and BITS_PER_FRAME (bits/frame)
    // SAMPLE_DIV = ceil( CLK * BITS_PER_FRAME / (8 * BAUD) )
    `define SAMPLE_DIV_FROM_BAUD(CLK, BAUD, BITS) \
            `CEIL_DIV( (CLK) * (BITS), (8 * (BAUD)) )

    localparam int BITS_PER_FRAME = (PARITY == "NONE") ? 10 : 11;
    localparam int SAMPLE_DIV = `SAMPLE_DIV_FROM_BAUD(CLK_FREQ, BAUD_RATE, BITS_PER_FRAME);

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

    //------------------------------------------------------------
    // 2) Byte assembler
    //------------------------------------------------------------
    logic [7:0] byte_buffer;
    logic [2:0] bit_counter;
    logic       byte_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_buffer <= '0;
            bit_counter <= 3'd0;
            byte_ready  <= 1'b0;
        end else begin
            byte_ready <= 1'b0;

            if (start && sample_pulse && !uart_busy) begin
                byte_buffer <= {trng_raw, byte_buffer[7:1]};
                if (bit_counter == 3'd7) begin
                    bit_counter <= 3'd0;
                    byte_ready  <= 1'b1;      // one byte complete
                end else begin
                    bit_counter <= bit_counter + 1'b1;
                end
            end
        end
    end

    //------------------------------------------------------------
    // 3) UART start
    //------------------------------------------------------------
    logic uart_tx_start;
    logic uart_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx_start <= 1'b0;
        end else begin
            uart_tx_start <= byte_ready;   // pulse for 1 cycle
        end
    end

    uart_tx #(
        .CLK_FREQ    (CLK_FREQ),
        .BAUD_RATE   (BAUD_RATE),
        .PARITY_TYPE (PARITY)
    ) uart_tx_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (byte_buffer),
        .tx_start (uart_tx_start),
        .uart_tx  (uart_tx),
        .tx_busy  (uart_busy)
    );

endmodule