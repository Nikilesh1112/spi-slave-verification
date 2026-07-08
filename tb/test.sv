//=============================================================================
// File        : test.sv
// Description : Test class containing all test scenarios for the SPI
//               Slave verification environment. A single class holds
//               every test as a separate task; top_tb.sv selects which
//               one to run using a +TESTNAME plusarg (read via
//               $value$plusargs), so no elaborate factory/registration
//               mechanism is needed.
//
//               Available tests (see docs/test_plan.md for full details):
//                 smoke_test        - one simple byte transfer, sanity check
//                 random_test       - randomized bursts, the main regression
//                 reset_test        - reset asserted mid-transaction
//                 corner_test       - 0x00, 0xFF, alternating patterns
//                 back_to_back_test - long burst with CS held low throughout
//                 pattern_test      - walking-1/walking-0 data patterns
//=============================================================================

class test;

  environment env;

  virtual spi_if.DRIVER  drv_vif;
  virtual spi_if.MONITOR mon_vif;

  function new(virtual spi_if.DRIVER  drv_vif,
               virtual spi_if.MONITOR mon_vif);
    this.drv_vif = drv_vif;
    this.mon_vif = mon_vif;
    env = new(drv_vif, mon_vif);
  endfunction

  // -------------------------------------------------------------------
  // build_txn: small helper to build one transaction with given fields,
  // avoiding repetitive "new(); assign fields;" blocks in every test.
  // -------------------------------------------------------------------
  function transaction build_txn(bit [7:0] mosi_data,
                                  bit [7:0] miso_data,
                                  bit       cs_hold_after);
    transaction t = new();
    t.mosi_data     = mosi_data;
    t.miso_data     = miso_data;
    t.cs_hold_after = cs_hold_after;
    t.spi_mode      = 2'b00;
    return t;
  endfunction

  // =====================================================================
  // TEST 1: smoke_test
  // Simplest possible sanity test - one MOSI byte, one MISO byte,
  // single transfer, CS pulses low then high. If this fails, nothing
  // else in the DUT/TB integration is trustworthy.
  // =====================================================================
  task smoke_test();
    transaction q[$];
    $display("\n===================== SMOKE TEST =====================\n");
    env.reset_env();
    env.run();

    q.push_back(build_txn(8'hA5, 8'h3C, 1'b0));
    env.gen.run_directed(q);

    // Allow time for the single transfer + pipeline to complete
    repeat (120) @(posedge drv_vif.i_Clk);
    env.report();
  endtask

  // =====================================================================
  // TEST 2: random_test
  // Main regression workhorse - fully randomized transactions with a
  // healthy mix of single-byte and back-to-back bursts.
  // =====================================================================
  task random_test(int num_txns = 30);
    $display("\n===================== RANDOM TEST =====================\n");
    env.reset_env();
    env.run();

    env.gen.num_txns = num_txns;
    env.gen.run_random();

    // Wait long enough for all bursts to complete. Each byte takes
    // roughly 8 SPI clock periods; give generous margin.
    repeat (num_txns * 120) @(posedge drv_vif.i_Clk);
    env.report();
  endtask

  // =====================================================================
  // TEST 3: reset_test
  // Verifies the DUT recovers cleanly from a mid-transaction reset:
  // start a transfer, assert reset partway through, release reset,
  // then confirm a fresh transfer afterward works correctly.
  // =====================================================================
  task reset_test();
    transaction q[$];
    $display("\n===================== RESET TEST =====================\n");
    env.reset_env();
    env.run();

    // Kick off a transfer, then rip reset in the middle of it
    fork
      begin
        q.push_back(build_txn(8'h5A, 8'hC3, 1'b0));
        env.gen.run_directed(q);
      end
      begin
        // Wait partway into the byte, then assert reset asynchronously
        repeat (3) @(posedge drv_vif.i_SPI_Clk);
        $display("[TEST] Forcing i_Rst_L low mid-transaction at time %0t", $time);
        drv_vif.i_Rst_L <= 1'b0;
        repeat (5) @(posedge drv_vif.i_Clk);
        drv_vif.i_Rst_L <= 1'b1;
        $display("[TEST] Released i_Rst_L at time %0t", $time);
      end
    join

    // Bring CS back to idle and give the bus time to settle after the
    // forced reset before starting a clean transfer.
    drv_vif.i_SPI_CS_n <= 1'b1;
    repeat (10) @(posedge drv_vif.i_Clk);

    // Now confirm a completely normal transfer works after reset
    q.delete();
    q.push_back(build_txn(8'h11, 8'h22, 1'b0));
    env.gen.run_directed(q);
    repeat (120) @(posedge drv_vif.i_Clk);

    env.report();
  endtask

  // =====================================================================
  // TEST 4: corner_test
  // Directed test focused on edge-value data: all-zeros, all-ones, and
  // alternating bit patterns, both as MOSI and MISO data.
  // =====================================================================
  task corner_test();
    transaction q[$];
    $display("\n===================== CORNER CASE TEST =====================\n");
    env.reset_env();
    env.run();

    q.push_back(build_txn(8'h00, 8'h00, 1'b1)); // all zeros, hold CS
    q.push_back(build_txn(8'hFF, 8'hFF, 1'b1)); // all ones, hold CS
    q.push_back(build_txn(8'hAA, 8'h55, 1'b1)); // alternating pattern
    q.push_back(build_txn(8'h55, 8'hAA, 1'b0)); // inverse pattern, end burst

    env.gen.run_directed(q);
    repeat (q.size() * 120) @(posedge drv_vif.i_Clk);
    env.report();
  endtask

  // =====================================================================
  // TEST 5: back_to_back_test
  // Verifies multiple bytes transferred in one continuous CS_n-low
  // burst (this exercises the DUT's ability to keep shifting bytes
  // without CS toggling between every byte).
  // =====================================================================
  task back_to_back_test(int burst_len = 8);
    transaction q[$];
    $display("\n===================== BACK-TO-BACK TEST =====================\n");
    env.reset_env();
    env.run();

    for (int i = 0; i < burst_len; i++) begin
      bit last = (i == burst_len - 1);
      q.push_back(build_txn(8'(i), 8'(burst_len - i), !last));
    end

    env.gen.run_directed(q);
    repeat (burst_len * 120) @(posedge drv_vif.i_Clk);
    env.report();
  endtask

  // =====================================================================
  // TEST 6: pattern_test
  // Walking-1 and walking-0 data patterns on MOSI, useful for catching
  // any bit-ordering mistakes in either the DUT or the testbench itself.
  // =====================================================================
  task pattern_test();
    transaction q[$];
    $display("\n===================== DATA PATTERN TEST =====================\n");
    env.reset_env();
    env.run();

    // Walking 1s
    for (int i = 0; i < 8; i++) begin
      q.push_back(build_txn(8'h01 << i, 8'h80 >> i, 1'b1));
    end
    // Walking 0s (inverse), last one ends the burst
    for (int i = 0; i < 8; i++) begin
      bit last = (i == 7);
      q.push_back(build_txn(~(8'h01 << i), ~(8'h80 >> i), !last));
    end

    env.gen.run_directed(q);
    repeat (q.size() * 120) @(posedge drv_vif.i_Clk);
    env.report();
  endtask

endclass : test 
