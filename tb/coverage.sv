//=============================================================================
// File        : coverage.sv
// Description : Functional coverage for the SPI Slave verification
//               environment. Samples transactions coming from the
//               monitor, and also samples reset activity directly off
//               the interface.
//
//               Coverage goals (as per verification plan, docs/test_plan.md):
//                 - reset asserted/deasserted at least once
//                 - MOSI data values: include 0x00, 0xFF, alternating
//                   patterns, and general random spread (bins)
//                 - MISO data values: same bins as MOSI
//                 - back-to-back transfers (cs_hold_after = 1) exercised
//                 - single-byte transfers (cs_hold_after = 0) exercised
//                 - both clock edges of SCLK toggle during a transfer
//=============================================================================

class coverage;

  virtual spi_if.MONITOR vif;
  mailbox #(transaction) mon2cov_mbx;

  transaction cov_txn;   // sampled by covergroup below

  // ---------------------------------------------------------------
  // Covergroup: transaction-level coverage (data values, CS behavior)
  // ---------------------------------------------------------------
  covergroup cg_transaction;
    option.per_instance = 1;

    cp_mosi_data : coverpoint cov_txn.mosi_data {
      bins zero        = {8'h00};
      bins all_ones     = {8'hFF};
      bins alt_pattern  = {8'hAA, 8'h55};
      bins low_range    = {[8'h01 : 8'h3F]};
      bins mid_range    = {[8'h40 : 8'hBF]};
      bins high_range   = {[8'hC0 : 8'hFE]};
    }

    cp_miso_data : coverpoint cov_txn.miso_data {
      bins zero        = {8'h00};
      bins all_ones     = {8'hFF};
      bins alt_pattern  = {8'hAA, 8'h55};
      bins low_range    = {[8'h01 : 8'h3F]};
      bins mid_range    = {[8'h40 : 8'hBF]};
      bins high_range   = {[8'hC0 : 8'hFE]};
    }

    cp_cs_hold : coverpoint cov_txn.cs_hold_after {
      bins single_byte_txn = {0};  // CS deasserted right after this byte
      bins back_to_back    = {1};  // CS held low, another byte follows
    }

    // Cross MOSI data range with back-to-back behavior, to make sure
    // we see extreme data values both as standalone and burst transfers
    cx_data_burst : cross cp_mosi_data, cp_cs_hold;

  endgroup

  // ---------------------------------------------------------------
  // Covergroup: reset coverage, sampled directly on interface changes
  // ---------------------------------------------------------------
  covergroup cg_reset @(posedge vif.i_Clk);
    option.per_instance = 1;
    cp_reset_state : coverpoint vif.i_Rst_L {
      bins in_reset     = {0};
      bins out_of_reset = {1};
    }
  endgroup

  // ---------------------------------------------------------------
  // Covergroup: SPI clock edge activity while CS is asserted
  // ---------------------------------------------------------------
  covergroup cg_spi_clk @(posedge vif.i_SPI_Clk or negedge vif.i_SPI_Clk);
    option.per_instance = 1;
    cp_clk_edge : coverpoint vif.i_SPI_Clk iff (!vif.i_SPI_CS_n) {
      bins rising_seen  = {1};
      bins falling_seen = {0};
    }
  endgroup

  function new(virtual spi_if.MONITOR vif,
               mailbox #(transaction) mon2cov_mbx);
    this.vif         = vif;
    this.mon2cov_mbx = mon2cov_mbx;
    cg_transaction = new();
    cg_reset       = new();
    cg_spi_clk     = new();
  endfunction

  // -------------------------------------------------------------------
  // run: main coverage loop - waits for transactions from monitor and
  // samples the transaction covergroup. Reset/clk covergroups sample
  // themselves automatically since they are clocked covergroups.
  // -------------------------------------------------------------------
  task run();
    forever begin
      mon2cov_mbx.get(cov_txn);
      cg_transaction.sample();
    end
  endtask

  // -------------------------------------------------------------------
  // report: print final coverage summary
  // -------------------------------------------------------------------
  function void report();
    $display("=========================================================");
    $display("[COVERAGE] FINAL REPORT");
    $display("  Transaction coverage : %0.2f %%", cg_transaction.get_coverage());
    $display("  Reset coverage       : %0.2f %%", cg_reset.get_coverage());
    $display("  SPI clock coverage   : %0.2f %%", cg_spi_clk.get_coverage());
    $display("=========================================================");
  endfunction

endclass : coverage
