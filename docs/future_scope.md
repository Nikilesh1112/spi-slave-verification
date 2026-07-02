# Future Scope

Ideas for extending this project, roughly ordered from "next logical
step" to "bigger undertaking":

1. **Verify all 4 SPI modes.** Parameterize the driver and monitor's
   sampling/shifting edges based on CPOL/CPHA (matching the DUT's
   `SPI_MODE` parameter), and add a `mode_test` that sweeps through
   all four modes with the same data patterns.

2. **Add a coverage-driven regression loop.** Instead of a fixed
   `num_txns` in `random_test`, loop `random_test` with an increasing
   seed until `cg_transaction.get_coverage()` reaches 100%, then stop -
   a simple version of coverage-driven verification.

3. **Add a reference model class.** Currently the scoreboard's
   "expected" values come directly from what the driver preloaded.
   A cleaner architecture would have a dedicated `reference_model`
   class that predicts DUT behavior independently, so the scoreboard
   compares two independent sources of truth (closer to how larger
   verification teams structure scoreboards).

4. **Add UVM port of this environment.** Once comfortable with this
   plain-class version, re-implement the same environment using
   `uvm_component`, `uvm_sequence`, and `uvm_scoreboard` as a second,
   parallel environment - a great way to demonstrate growth from
   "verification fundamentals" to "industry-standard methodology" on
   a resume.

5. **Add code/toggle coverage collection** using the simulator's
   built-in coverage database (e.g. `-cm line+cond+fsm+tgl` in VCS),
   and merge it with the functional coverage report.

6. **CDC-aware assertions.** Add assertions that specifically check
   the two-flop synchronizer behavior inside the DUT (`r2_RX_Done`,
   `r3_RX_Done`) for correct domain-crossing behavior under different
   clock ratios between `i_Clk` and `i_SPI_Clk`.

7. **Multi-slave bus test.** Instantiate two `SPI_Slave` DUTs sharing
   one MISO line with different CS_n signals, and verify correct
   tri-state arbitration between them.

8. **Continuous Integration.** Add a GitHub Actions workflow that
   runs `make lint` (Verilator, free, works in CI out of the box) on
   every push, as a basic sanity gate even though the full class-based
   regression needs a licensed simulator that can't run in free CI.
