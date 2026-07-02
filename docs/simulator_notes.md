# Simulator Notes - Read This Before Running Anything

This project's testbench intentionally uses real, professional
SystemVerilog verification constructs: classes, `mailbox`,
`rand`/`constraint`/`randomize()`, `covergroup`, and concurrent SVA
(`assert property`). This is exactly what a DV engineer uses day to
day - and it is also exactly the set of features that free/open-source
simulators historically have **not** fully supported.

This section documents what was actually tested, so you don't waste
time chasing confusing error messages.

## What was tested for this project

| Tool | Version | Result |
|---|---|---|
| Icarus Verilog | 12.0 (stable) | Does **not** support `constraint` blocks, `randomize()`, parameterized `mailbox #(type)`, or `assert property` (concurrent SVA). Confirmed by direct compilation testing - these are known, longstanding gaps in Icarus Verilog's SystemVerilog class/OOP support. |
| Verilator | 5.020 (Ubuntu apt package) | Cannot elaborate the class-based testbench (no mailbox/constraint support in this version). **However**, it cleanly lints the synthesizable DUT RTL with zero errors/warnings (`verilator --lint-only rtl/SPI_Slave.v`), which is genuinely useful and is wired up as the `make lint` target. |

Antmicro/CHIPS Alliance have been adding class, mailbox, and
constrained-randomization support to Verilator's development branch
(see their blog posts on "Constrained Randomization in Verilator"),
but as of this writing that work is on Verilator's bleeding-edge
builds, not the stable release most people install via `apt`. If
you build a very recent Verilator from source, some of this may work
- but it's not the recommended path for a fresher just trying to get
a portfolio project running.

## Recommended free option: EDA Playground + Aldec Riviera-PRO

[EDA Playground](https://www.edaplayground.com) gives free, browser-based
access to **Aldec Riviera-PRO**, a commercial-grade simulator with full
SystemVerilog class/OOP, mailbox, constraint, and SVA support - no
company or university email required, a Google login is enough. This
is a widely used, well-known platform among verification students and
freshers, and mentioning it in an interview is a positive signal, not
a negative one - it shows you understand real tooling constraints.

See `docs/how_to_run.md` for the exact steps to paste this project's
files into EDA Playground and run each test.

## If you have access to a commercial simulator

If your college or employer gives you access to Synopsys VCS, Cadence
Xcelium, or Siemens Questa, the `Makefile` in this repository already
has targets for all three (`make run SIM=vcs`, `SIM=xcelium`,
`SIM=questa`) plus `SIM=riviera` for a locally-installed Riviera-PRO.
These are the tools actually used in industry, and this project's
testbench was written to be directly portable to them with no changes.

## Summary

| Task | Tool | Works for free, locally? |
|---|---|---|
| Lint DUT RTL | Verilator | Yes |
| View DUT syntax/structure | Icarus Verilog | Partially (plain RTL only) |
| Run the full class-based testbench | Aldec Riviera-PRO via EDA Playground | Yes (browser, free) |
| Run the full class-based testbench | VCS / Xcelium / Questa | Only with a license |
