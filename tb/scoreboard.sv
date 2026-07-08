//=============================================================================
// File        : scoreboard.sv
// Description : Checks that the SPI Slave DUT behaves correctly by
//               comparing:
//
//                 1) What the monitor observed on the MOSI line (the byte
//                    the "master" sent) against the byte the DUT reports
//                    on o_RX_Byte (in the i_Clk domain, via o_RX_DV pulse).
//
//                 2) What the monitor observed on the MISO line (the byte
//                    the DUT actually shifted out) against the byte that
//                    was pre-loaded into the DUT via i_TX_Byte/i_TX_DV
//                    for that transfer.
//
//               This scoreboard is intentionally simple: an in-order
//               transaction-level comparison using mailboxes plus a
//               scoreboard-local reference queue. No fancy pending-CAM
//               or associative-array pattern is used, because SPI in
//               this environment is inherently in-order and single-
//               threaded (one byte transfer completes before the next
//               starts).
//=============================================================================

class scoreboard;

  virtual spi_if.MONITOR vif;
  mailbox #(transaction) mon2scb_mbx;

  // Reference queue of "expected MISO byte" values, pushed by the driver
  // side (through the environment) each time it preloads i_TX_Byte for
  // an upcoming transfer. The scoreboard pops one entry per observed
  // transaction to know what MISO *should* have been.
  bit [7:0] expected_miso_q[$];

  // Mailbox used to hand off each observed MOSI byte from
  // check_miso_transactions() to check_mosi_against_rx_dv(), so the
  // RX-path check blocks until the monitor has actually recorded the
  // byte instead of racing ahead of it.
  mailbox #(bit [7:0]) last_mosi_seen_mbx;

  int num_checked = 0;
  int num_passed  = 0;
  int num_failed  = 0;

  function new(virtual spi_if.MONITOR vif,
               mailbox #(transaction) mon2scb_mbx);
    this.vif              = vif;
    this.mon2scb_mbx      = mon2scb_mbx;
    this.last_mosi_seen_mbx = new();
  endfunction

  // Called by the environment/driver whenever a new MISO byte is
  // preloaded, so the scoreboard knows what to expect.
  function void push_expected_miso(bit [7:0] data);
    expected_miso_q.push_back(data);
  endfunction

  // -------------------------------------------------------------------
  // run: main scoreboard loop. Also independently watches o_RX_DV in
  // the i_Clk domain to cross-check the DUT's own reported RX byte
  // against what the monitor captured directly off the MOSI line.
  // -------------------------------------------------------------------
  task run();
    fork
      check_mosi_against_rx_dv();
      check_miso_transactions();
    join_none
  endtask

  // ---------------------------------------------------------------
  // check_mosi_against_rx_dv:
  // Independently samples o_RX_DV/o_RX_Byte and compares it against
  // the MOSI byte last observed by the monitor. This directly
  // verifies the DUT's clock-domain-crossing logic (SPI clock domain
  // -> system clock domain) is reporting the correct byte.
  // ---------------------------------------------------------------
  task check_mosi_against_rx_dv();
    forever begin
      @(posedge vif.i_Clk);
      if (vif.o_RX_DV) begin
        bit [7:0] exp_mosi;

        num_checked++;

        // Wait until the monitor has provided the corresponding MOSI byte.
        last_mosi_seen_mbx.get(exp_mosi);

        if (vif.o_RX_Byte === exp_mosi) begin
          $display("[SCOREBOARD] PASS (RX path): DUT received 0x%02h", exp_mosi);
          num_passed++;
        end
        else begin
          $error("[SCOREBOARD] FAIL (RX path): DUT received=0x%02h expected=0x%02h",
                 vif.o_RX_Byte, exp_mosi);
          num_failed++;
        end
      end
    end
  endtask

  // ---------------------------------------------------------------
  // check_miso_transactions:
  // Consumes monitor transactions (mosi_data/miso_data pairs captured
  // directly off the bus) and:
  //   - records the mosi_data into last_mosi_seen_mbx for RX-path check
  //   - compares miso_data against the expected preloaded TX byte
  // ---------------------------------------------------------------
  task check_miso_transactions();
    transaction txn;
    forever begin
      mon2scb_mbx.get(txn);
      last_mosi_seen_mbx.put(txn.mosi_data);

      num_checked++;
      if (expected_miso_q.size() == 0) begin
        $warning("[SCOREBOARD] MISO observed=0x%0h but no expected value was pushed (check testbench sequencing)",
                  txn.miso_data);
      end
      else begin
        bit [7:0] exp_miso = expected_miso_q.pop_front();
        if (txn.miso_data === exp_miso) begin
          num_passed++;
          $display("[SCOREBOARD] PASS (TX path): MISO observed=0x%0h matches expected=0x%0h",
                    txn.miso_data, exp_miso);
        end
        else begin
          num_failed++;
          $error("[SCOREBOARD] FAIL (TX path): MISO observed=0x%0h != expected=0x%0h",
                  txn.miso_data, exp_miso);
        end
      end
    end
  endtask

  // -------------------------------------------------------------------
  // report: print final pass/fail summary. Called at end of test.
  // -------------------------------------------------------------------
  function void report();
    $display("=========================================================");
    $display("[SCOREBOARD] FINAL REPORT");
    $display("  Total Checks : %0d", num_checked);
    $display("  Passed       : %0d", num_passed);
    $display("  Failed       : %0d", num_failed);
    if (num_failed == 0)
      $display("  RESULT       : TEST PASSED");
    else
      $display("  RESULT       : TEST FAILED");
    $display("=========================================================");
  endfunction

endclass : scoreboard 