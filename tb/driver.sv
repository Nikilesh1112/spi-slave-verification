//=============================================================================
// File        : driver.sv
// Description : Drives transactions onto the SPI bus. Since the DUT is a
//               SPI SLAVE, the driver plays the role of the SPI MASTER:
//               it generates i_SPI_Clk, drives i_SPI_MOSI, and controls
//               i_SPI_CS_n. It also drives the system-side i_TX_Byte /
//               i_TX_DV signals to pre-load the byte the slave should
//               send back on MISO.
//
//               Only SPI Mode 0 (CPOL=0, CPHA=0) is used by default,
//               matching the DUT instantiation in top_tb.sv. This keeps
//               the driver logic simple for a fresher project - one
//               mode, clearly explained, instead of a generic 4-mode
//               bit-banger.
//
//               Mode 0 timing recap:
//                 - SCLK idles LOW
//                 - Data is sampled on the RISING edge of SCLK
//                 - Data changes on the FALLING edge of SCLK
//=============================================================================

class driver;

  virtual spi_if.DRIVER vif;
  mailbox #(transaction) gen2drv_mbx;
  event                  drv_done;

  // Handle to the scoreboard so the driver can tell it, ahead of time,
  // what MISO byte *should* come out of the DUT for each transfer
  // (the scoreboard has no other way to know what was preloaded).
  scoreboard scb;

  // Half period of the SPI clock, in time units of the simulation.
  // The system clock (i_Clk) period is defined in top_tb.sv; this SPI
  // clock is intentionally much slower than i_Clk, since the DUT
  // requires i_Clk to be at least 4x faster than i_SPI_Clk.
  time spi_half_period = 50ns; // => 10 MHz SPI clock (100ns period)

  function new(virtual spi_if.DRIVER vif,
               mailbox #(transaction) gen2drv_mbx,
               event drv_done,
               scoreboard scb);
    this.vif         = vif;
    this.gen2drv_mbx = gen2drv_mbx;
    this.drv_done    = drv_done;
    this.scb         = scb;
  endfunction

  // -------------------------------------------------------------------
  // reset_dut: apply and release reset, initialize bus to idle state
  // -------------------------------------------------------------------
  task reset_dut();
    vif.i_Rst_L    <= 1'b0;
    vif.i_SPI_CS_n <= 1'b1;   // CS idle (deasserted)
    vif.i_SPI_Clk  <= 1'b0;   // SCLK idle low (Mode 0)
    vif.i_SPI_MOSI <= 1'b0;
    vif.i_TX_DV    <= 1'b0;
    vif.i_TX_Byte  <= 8'h00;
    repeat (5) @(posedge vif.i_Clk);
    vif.i_Rst_L <= 1'b1;
    repeat (5) @(posedge vif.i_Clk);
    $display("[DRIVER] Reset applied and released at time %0t", $time);
  endtask

  // -------------------------------------------------------------------
  // preload_tx_byte: load the byte the DUT should shift out on MISO
  // for the *next* transaction, using the system clock domain.
  // -------------------------------------------------------------------
  task preload_tx_byte(bit [7:0] data);
    @(posedge vif.i_Clk);
    vif.i_TX_Byte <= data;
    vif.i_TX_DV   <= 1'b1;
    @(posedge vif.i_Clk);
    vif.i_TX_DV   <= 1'b0;

    // Tell the scoreboard what MISO should show for this transfer
    scb.push_expected_miso(data);
  endtask

  // -------------------------------------------------------------------
  // drive_byte: shifts one byte (MSB first) out on MOSI while sampling
  // MISO, using SPI Mode 0 timing. CS_n is asserted before the first
  // byte of a burst and only deasserted if cs_hold_after = 0.
  // -------------------------------------------------------------------
  task drive_byte(transaction txn, bit is_first_byte);

    // Pre-load what the slave should send back on MISO for this byte.
    preload_tx_byte(txn.miso_data);

    if (is_first_byte) begin
      vif.i_SPI_CS_n <= 1'b0;   // assert CS (active low) to start burst
      #(spi_half_period);       // small setup gap before first clock edge
    end

    for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      // Drive MOSI while clock is still low (data changes on falling edge,
      // sampled on rising edge - Mode 0)
      vif.i_SPI_MOSI <= txn.mosi_data[bit_idx];
      #(spi_half_period);

      vif.i_SPI_Clk <= 1'b1;    // rising edge -> DUT samples MOSI here
      #(spi_half_period);

      vif.i_SPI_Clk <= 1'b0;    // falling edge -> DUT/master change data
    end

    if (!txn.cs_hold_after) begin
      #(spi_half_period);
      vif.i_SPI_CS_n <= 1'b1;   // deassert CS, ends the transaction
      #(spi_half_period);
    end

  endtask

  // -------------------------------------------------------------------
  // run: main driver loop - pulls transactions from mailbox and drives
  // them onto the bus. Tracks whether we are mid-burst (CS already low)
  // to correctly assert CS only at the start of a new burst.
  // -------------------------------------------------------------------
  task run();
    transaction txn;
    bit         cs_currently_low = 1'b0;

    forever begin
      gen2drv_mbx.get(txn);
      txn.print("DRV");

      drive_byte(txn, !cs_currently_low);
      cs_currently_low = txn.cs_hold_after;

      // Small idle gap between independent bursts for readability in
      // waveforms and to guarantee CS pulse width is clearly visible.
      if (!txn.cs_hold_after) begin
        repeat (2) @(posedge vif.i_Clk);
      end
    end
  endtask

endclass : driver
