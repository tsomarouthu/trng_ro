`timescale 1ns/1ps

module tb_top_ro;

  reg  clk;
  reg  ro_en;
  wire ro_out;

  // --- Clock: 100 MHz (10ns period) ---
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // --- DUT ---
  ro dut (
    .ro_en (ro_en),
    .clk   (clk),
    .ro_out(ro_out)
  );

  // --- Stimulus ---
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_top);

    ro_en = 0;
    $display("[%0t] ro_en=0", $time);

    repeat (10) @(posedge clk);

    ro_en = 1;
    $display("[%0t] ro_en=1", $time);

    repeat (20) @(posedge clk);

    ro_en = 0;
    $display("[%0t] ro_en=0", $time);

    repeat (10) @(posedge clk);

    $display("[%0t] DONE", $time);
    $finish;
  end

  // --- Monitor output ---
  always @(posedge clk) begin
    $display("[%0t] clk ↑  ro_en=%0b  ro_out=%0b", $time, ro_en, ro_out);
  end

endmodule