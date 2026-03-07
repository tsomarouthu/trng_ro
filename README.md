# trng_ro
SystemVerilog implementation of an RO based TRNG targeted on Altera Cyclone-V FPGA

Credits: Base design is in Verilog which was given to me as part of attendance to course IL_1333 by Elena Dubrova from KTH

my work: 
1. Throughput: update baud_rate to 115200 so the data streaming would improve from 9.6Kbps to 110Kbps
2. Sampling: Add a fifo and sampling so that the design captures a trng_bit every nth microsecond. On the contrary, existing design packs first 8-bits on fast_clk, transmits data on uart_rate.
i.e.,
base design: fast capture followed by long silence

[   160 ns   ] [......................... 1 ms ...................... ] [   160 ns   ] [......................... 1 ms ...................... ]

[pack 8bits] [.........................skip trng bits...........] [pack 8bits] [.........................skip trng bits...........] 

1ms - uart frame rate for 9600 baud

updated: normalized capture and silence

[  15 us ][  15 us ][  15 us ][  15 us ][  15 us ][  15 us ][  15 us ][  15 us ] ..... repeat

[     b0   ][     b1   ][     b2   ][     b3   ][     b4   ][     b5   ][     b6   ][     b7   ] ..... repeat

15 us - This can be made to 12 us to match with uart frame rate 112500

3. RO scaling per cluster : Parameterize the design to have different number of ROs per each cluster
4. Placement constrains : Placement combination per each cluster at different corners
5. Systemverilog : Update existing Verilog to System Verilog to make use of  its usable constructs like generate statements.
