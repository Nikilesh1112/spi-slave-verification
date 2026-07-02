# Known Limitations

This project is intentionally scoped for a fresher-level portfolio
piece. The following limitations are known and deliberate, not
oversights:

1. **Only SPI Mode 0 is verified.** The DUT supports Modes 0-3 via
   its `SPI_MODE` parameter, but the driver, monitor, and assertions
   in this project all assume Mode 0 (CPOL=0, CPHA=0) timing. See
   `docs/future_scope.md` for how this could be extended.

2. **No multi-slave bus sharing test.** The DUT's MISO tri-state
   behavior (assertion A3) is checked for a single slave in isolation;
   a real multi-drop bus with several slaves sharing MISO is not
   modeled.

3. **No X-propagation / uninitialized-signal checking.** The
   testbench does not explicitly inject X values to check the DUT's
   robustness to uninitialized inputs at power-up before the first
   reset.

4. **CDC (clock domain crossing) checking is functional, not
   structural.** The scoreboard's RX-path check confirms the DUT
   reports the correct byte after crossing from the SPI clock domain
   to the system clock domain, but this project does not include a
   dedicated CDC linting run (e.g. Spyglass CDC) - that is a separate,
   specialized flow beyond this project's scope.

5. **No formal verification.** All checking is simulation-based (SVA
   assertions checked during simulation, not proven exhaustively with
   a formal tool).

6. **No code coverage / toggle coverage.** Only functional coverage
   is collected (`tb/coverage.sv`). Structural/code coverage would
   normally be layered on top in a full sign-off flow, using the
   simulator's own coverage database.

7. **Free-tool simulation limitations.** As documented in
   `docs/simulator_notes.md`, this testbench requires a simulator
   with full SystemVerilog class/OOP support. Icarus Verilog and the
   standard Verilator release do not support it; EDA Playground with
   Aldec Riviera-PRO (free) or a licensed VCS/Xcelium/Questa
   installation is required to actually run it.

8. **Assertion A4 (MOSI stability) is an immediate assertion, not a
   concurrent property.** This was a deliberate simplification (see
   the comment in `assertions/spi_assertions.sv`) to keep the check
   easy to read and reason about for a fresher, at the cost of being
   slightly less "textbook SVA style" than a fully concurrent
   property would be.
