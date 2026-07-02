# Verification Plan - SPI Slave

## 1. Objective

Verify that the `SPI_Slave` DUT (sourced from [nandland/spi-slave](https://github.com/nandland/spi-slave))
correctly implements SPI Mode 0 slave behavior:

- Correctly receives bytes shifted in on MOSI and reports them on the
  system-clock-domain `o_RX_Byte` / `o_RX_DV` interface.
- Correctly transmits pre-loaded bytes (`i_TX_Byte` / `i_TX_DV`) out on
  MISO, MSB first.
- Supports back-to-back multi-byte transfers while `i_SPI_CS_n` is held low.
- Correctly tri-states MISO when not selected (`i_SPI_CS_n` high).
- Recovers cleanly from reset at any point in a transaction.

## 2. DUT Under Test

| Item | Detail |
|---|---|
| Module | `SPI_Slave` |
| Source | https://github.com/nandland/spi-slave |
| File | `Verilog/source/SPI_Slave.v` |
| License | MIT |
| Parameter | `SPI_MODE` (this project verifies Mode 0: CPOL=0, CPHA=0) |

## 3. Verification Strategy

A directed + constrained-random, non-UVM, class-based SystemVerilog
testbench is used (see `docs/architecture.md`). Key strategy points:

- **Reference checking**: the scoreboard independently checks two
  data paths - the RX path (MOSI -> o_RX_Byte, crossing SPI clock
  domain to system clock domain) and the TX path (preloaded i_TX_Byte
  -> what actually appears on MISO).
- **Protocol correctness**: enforced continuously via SVA assertions
  bound to the interface (see `assertions/spi_assertions.sv`), independent
  of the scoreboard's data checking.
- **Functional coverage**: tracks that interesting data values, CS_n
  behavior (single-byte vs back-to-back), reset activity, and SPI
  clock edge toggling have all been exercised (see `tb/coverage.sv`).
- **Directed tests** cover known corner cases (0x00, 0xFF, alternating
  bit patterns, reset mid-transfer). **Random tests** provide broader
  coverage of the data space and burst-length combinations.

## 4. Verification Environment Components

| Component | File | Responsibility |
|---|---|---|
| Interface | `tb/spi_if.sv` | Bundles all DUT signals, provides driver/monitor modports |
| Transaction | `tb/transaction.sv` | Randomizable data item: one SPI byte transfer |
| Generator | `tb/generator.sv` | Produces random or directed transaction streams |
| Driver | `tb/driver.sv` | Drives the SPI bus (acting as SPI master) and preloads TX data |
| Monitor | `tb/monitor.sv` | Passively observes the bus, reconstructs transactions |
| Scoreboard | `tb/scoreboard.sv` | Checks RX and TX data paths against expected values |
| Coverage | `tb/coverage.sv` | Functional coverage on data values, CS behavior, reset, clock |
| Environment | `tb/environment.sv` | Instantiates and connects all components |
| Test | `tb/test.sv` | Contains all test scenarios |
| Top | `tb/top_tb.sv` | Clock/reset generation, DUT instantiation, test selection |
| Assertions | `assertions/spi_assertions.sv` | Protocol-level SVA checks |

## 5. Pass/Fail Criteria

A test is considered **PASSED** when:

1. The scoreboard reports zero failed checks (`num_failed == 0`) at
   the end of the test.
2. No SVA assertion fires an error during the run.
3. The simulation completes without hitting the watchdog timeout in
   `top_tb.sv`.

Regression as a whole passes when every test in
`regression/run_regression.sh` passes.

## 6. Coverage Closure Goal

100% functional coverage on all covergroups defined in
`tb/coverage.sv` (`cg_transaction`, `cg_reset`, `cg_spi_clk`) across
the full regression suite (not necessarily within a single test).

## 7. Out of Scope

- SPI Modes 1, 2, and 3 (DUT supports them via the `SPI_MODE`
  parameter, but this project's testbench and assertions are written
  for Mode 0 only - see `docs/future_scope.md`).
- Multi-slave bus sharing scenarios.
- Timing/gate-level (SDF-annotated) simulation.
- Formal verification (this project uses simulation-based SVA only).
