//=============================================================================
// File        : environment.sv
// Description : Top-level verification environment. Instantiates the
//               generator, driver, monitor, scoreboard, and coverage
//               components, connects them via mailboxes, and provides
//               simple run()/report() tasks for the test to call.
//
//               This is a plain SystemVerilog class (not uvm_env) -
//               construction and connection happen explicitly in the
//               constructor and build() method, which is easy to trace
//               for a fresher reading the code top-to-bottom.
//=============================================================================

class environment;

  // ---------------------------------------------------------------
  // Virtual interface handles (driver side, monitor side)
  // ---------------------------------------------------------------
  virtual spi_if.DRIVER  drv_vif;
  virtual spi_if.MONITOR mon_vif;

  // ---------------------------------------------------------------
  // Components
  // ---------------------------------------------------------------
  generator  gen;
  driver     drv;
  monitor    mon;
  scoreboard scb;
  coverage   cov;

  // ---------------------------------------------------------------
  // Mailboxes connecting the components
  // ---------------------------------------------------------------
  mailbox #(transaction) gen2drv_mbx;
  mailbox #(transaction) mon2scb_mbx;
  mailbox #(transaction) mon2cov_mbx;

  event drv_done;

  function new(virtual spi_if.DRIVER  drv_vif,
               virtual spi_if.MONITOR mon_vif);
    this.drv_vif = drv_vif;
    this.mon_vif = mon_vif;

    gen2drv_mbx = new();
    mon2scb_mbx = new();
    mon2cov_mbx = new();

    scb = new(mon_vif, mon2scb_mbx);
    gen = new(gen2drv_mbx, drv_done);
    drv = new(drv_vif, gen2drv_mbx, drv_done, scb);
    mon = new(mon_vif, mon2scb_mbx, mon2cov_mbx);
    cov = new(mon_vif, mon2cov_mbx);
  endfunction

  // -------------------------------------------------------------------
  // reset_env: applies reset through the driver before any test runs
  // -------------------------------------------------------------------
  task reset_env();
    drv.reset_dut();
  endtask

  // -------------------------------------------------------------------
  // run: starts all the always-running components (monitor, scoreboard,
  // coverage, driver) in parallel. Tests call gen.run_random() or
  // gen.run_directed() separately, then wait for the pipeline to drain.
  // -------------------------------------------------------------------
  task run();
    fork
      drv.run();
      mon.run();
      scb.run();
      cov.run();
    join_none
  endtask

  // -------------------------------------------------------------------
  // report: prints scoreboard + coverage summary at end of test
  // -------------------------------------------------------------------
  function void report();
    scb.report();
    cov.report();
  endfunction

endclass : environment
