`timescale 1ns/1ps

module tb_top;

  // Match trng_top defaults
  localparam int  CLK_FREQ = 50_000_000;  // Hz
  localparam int  BAUD     = 3_000_000;      // bps
  localparam time T_CLK    = 20ns;        // 50 MHz

  // DUT I/O
  reg               CLOCK_50;
  reg        [0:0]  KEY;      // active-low reset
  wire       [1:0]  LED;
  reg        [1:0]  SW;       // SW[0]=ro_en, SW[1]=start
  reg               UART_RX;
  wire              UART_TX;

  // 50 MHz clock
  initial begin
    CLOCK_50 = 1'b0;
    forever #(T_CLK/2) CLOCK_50 = ~CLOCK_50;
  end

  // DUT
  trng_top #(
    .CLK_FREQ (CLK_FREQ),
    .BAUD_RATE(BAUD),
    .PARITY   ("EVEN")
  ) dut (
    .CLOCK_50 (CLOCK_50),
    .KEY      (KEY),
    .LED      (LED),
    .SW       (SW),
    .UART_RX  (UART_RX),
    .UART_TX  (UART_TX)
  );

  // VCD
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_top);
  end

  // Stimulus: reset → ro_en → start → run a short while
  initial begin
    // defaults
    KEY     = 1'b0;     // hold reset low (active)
    SW      = 2'b00;
    UART_RX = 1'b1;     // idle-high

    $display("[%0t] RESET active", $time);
    repeat (10) @(posedge CLOCK_50);

    KEY[0] = 1'b1;      // release reset
    $display("[%0t] RESET released", $time);

    repeat (50) @(posedge CLOCK_50);
    SW[0] = 1'b1;       // enable ROs (debounced in DUT)
    $display("[%0t] SW0=1 (ro_en)", $time);

    repeat (50) @(posedge CLOCK_50);
    SW[1] = 1'b1;       // start streaming (debounced in DUT)
    $display("[%0t] SW1=1 (start)", $time);

    // Let it run; in SIMULATION uart_tx bypass prints bytes quickly
    //#(2_000_000);       // 20 ms of sim time
    #(100_000);
    $display("[%0t] DONE", $time);
    $finish;
  end

  // Optional: observe UART activity (bypass model prints bytes itself)
  // always @(posedge CLOCK_50) $strobe("[%0t] UART_TX=%b", $time, UART_TX);

endmodule