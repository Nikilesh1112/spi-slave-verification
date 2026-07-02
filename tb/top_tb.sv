//=============================================================================
// File        : top_tb.sv
// Description : Top-level testbench module. Responsibilities:
//                 - generate the system clock (i_Clk)
//                 - instantiate the spi_if interface
//                 - instantiate the SPI_Slave DUT and connect it to the
//                   interface
//                 - bind in the protocol assertions module
//                 - select and run one test based on +TESTNAME plusarg
//                 - dump waveforms (VCD) for debug
//
//               Run with, e.g.:
//                 make run TEST=smoke_test
//               which passes +TESTNAME=smoke_test to the simulator.
//=============================================================================

`timescale 1ns / 1ps

module top_tb;

  // ---------------------------------------------------------------
  // System clock generation: 100 MHz (10ns period)
  // Must be at least 4x faster than the SPI clock the driver
  // generates (10 MHz / 100ns period), per DUT requirements.
  // ---------------------------------------------------------------
  logic i_Clk;
  initial i_Clk = 1'b0;
  always #5 i_Clk = ~i_Clk;   // 10ns period -> 100MHz

  // ---------------------------------------------------------------
  // Interface instantiation
  // ---------------------------------------------------------------
  spi_if u_spi_if (.i_Clk(i_Clk));

  // ---------------------------------------------------------------
  // DUT instantiation - SPI_MODE=0 (CPOL=0, CPHA=0), matching the
  // driver's bit-banging timing in driver.sv
  // ---------------------------------------------------------------
  SPI_Slave #(
    .SPI_MODE (0)
  ) u_dut (
    .i_Rst_L     (u_spi_if.i_Rst_L),
    .i_Clk       (u_spi_if.i_Clk),

    .o_RX_DV     (u_spi_if.o_RX_DV),
    .o_RX_Byte   (u_spi_if.o_RX_Byte),

    .i_TX_DV     (u_spi_if.i_TX_DV),
    .i_TX_Byte   (u_spi_if.i_TX_Byte),

    .i_SPI_Clk   (u_spi_if.i_SPI_Clk),
    .o_SPI_MISO  (u_spi_if.o_SPI_MISO),
    .i_SPI_MOSI  (u_spi_if.i_SPI_MOSI),
    .i_SPI_CS_n  (u_spi_if.i_SPI_CS_n)
  );

  // ---------------------------------------------------------------
  // Protocol assertions - bound to the interface, see
  // assertions/spi_assertions.sv for details
  // ---------------------------------------------------------------
  spi_assertions u_spi_assertions (
    .i_Clk       (u_spi_if.i_Clk),
    .i_Rst_L     (u_spi_if.i_Rst_L),
    .i_SPI_Clk   (u_spi_if.i_SPI_Clk),
    .i_SPI_MOSI  (u_spi_if.i_SPI_MOSI),
    .i_SPI_CS_n  (u_spi_if.i_SPI_CS_n),
    .o_SPI_MISO  (u_spi_if.o_SPI_MISO),
    .o_RX_DV     (u_spi_if.o_RX_DV),
    .o_RX_Byte   (u_spi_if.o_RX_Byte)
  );

  // ---------------------------------------------------------------
  // Waveform dumping (VCD, viewable with GTKWave or Verdi)
  // ---------------------------------------------------------------
  initial begin
    $dumpfile("waves/spi_slave_tb.vcd");
    $dumpvars(0, top_tb);
  end

  // ---------------------------------------------------------------
  // Test selection and execution
  // ---------------------------------------------------------------
  test t;
  string test_name;

  initial begin
    t = new(u_spi_if.DRIVER, u_spi_if.MONITOR);

    if (!$value$plusargs("TESTNAME=%s", test_name)) begin
      test_name = "smoke_test";   // default test if none specified
    end

    $display("=========================================================");
    $display(" SPI SLAVE VERIFICATION - Starting test: %0s", test_name);
    $display("=========================================================");

    case (test_name)
      "smoke_test"        : t.smoke_test();
      "random_test"        : t.random_test();
      "reset_test"          : t.reset_test();
      "corner_test"         : t.corner_test();
      "back_to_back_test"   : t.back_to_back_test();
      "pattern_test"        : t.pattern_test();
      default : begin
        $error("[TOP_TB] Unknown TESTNAME '%0s'. Valid options: smoke_test, random_test, reset_test, corner_test, back_to_back_test, pattern_test",
                test_name);
      end
    endcase

    $display("=========================================================");
    $display(" SPI SLAVE VERIFICATION - Test '%0s' complete", test_name);
    $display("=========================================================");

    #100;
    $finish;
  end

  // ---------------------------------------------------------------
  // Simulation timeout watchdog - prevents a hung testbench from
  // running forever (e.g. if a mailbox blocks unexpectedly)
  // ---------------------------------------------------------------
  initial begin
    #1_000_000; // 1ms of simulated time, generous for these tests
    $error("[TOP_TB] TIMEOUT - simulation did not finish in time. Possible hang.");
    $finish;
  end

endmodule : top_tb
