//=============================================================================
// File        : transaction.sv
// Description : Transaction (sequence item) class for the SPI Slave TB.
//
//               One transaction = one SPI byte transfer. Since this DUT
//               supports multiple bytes per CS_n assertion (back-to-back
//               transfers while CS stays low), we also model that at the
//               generator level by issuing several transactions with
//               cs_hold_after = 1.
//
//               This class is intentionally simple: no factory, no
//               inheritance tricks. Just a plain class with randomizable
//               fields, constraints, and a print/copy helper - exactly
//               what a fresher-built non-UVM environment should look like.
//=============================================================================

class transaction;

  // -------------------------------------------------------------------
  // Data fields
  // -------------------------------------------------------------------
  rand bit [7:0] mosi_data;     // byte driven from master -> slave (MOSI)
  rand bit [7:0] miso_data;     // byte pre-loaded into slave for MISO
                                 // (this is what the driver writes into
                                 //  i_TX_Byte/i_TX_DV before the transfer)

  // Controls whether CS_n stays LOW after this byte (back-to-back mode)
  // or goes HIGH (ends the transaction) after this byte.
  rand bit       cs_hold_after;

  // Which SPI mode to use for this transaction (0,1,2,3).
  // Kept constant for most tests, randomized only in the SPI-mode test.
  rand bit [1:0] spi_mode;

  // -------------------------------------------------------------------
  // Constraints
  // -------------------------------------------------------------------

  // By default, favor ending the transaction (cs_hold_after = 0) about
  // half the time, and continuing back-to-back the other half. This gives
  // the random test a healthy mix of single-byte and multi-byte bursts.
  constraint c_cs_hold_dist {
    cs_hold_after dist { 0 := 50, 1 := 50 };
  }

  // Keep spi_mode at 0 unless a test explicitly randomizes it separately.
  // (Mode is normally a static DUT parameter, not something that changes
  // mid-simulation on real hardware, so most tests hold this fixed.)
  constraint c_default_mode {
    spi_mode == 2'b00;
  }

  // -------------------------------------------------------------------
  // Utility: deep copy
  // -------------------------------------------------------------------
  function transaction copy();
    transaction t = new();
    t.mosi_data     = this.mosi_data;
    t.miso_data     = this.miso_data;
    t.cs_hold_after = this.cs_hold_after;
    t.spi_mode      = this.spi_mode;
    return t;
  endfunction

  // -------------------------------------------------------------------
  // Utility: readable print for logging/debug
  // -------------------------------------------------------------------
  function void print(string tag = "TXN");
    $display("[%0s] mosi_data=0x%0h miso_data=0x%0h cs_hold_after=%0b spi_mode=%0d",
              tag, mosi_data, miso_data, cs_hold_after, spi_mode);
  endfunction

endclass : transaction
