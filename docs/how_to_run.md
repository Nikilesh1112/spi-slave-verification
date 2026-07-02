# How To Run This Testbench (Free, No Install)

This guide walks through running the SPI Slave testbench for free,
using EDA Playground with the Aldec Riviera-PRO simulator. No paid
license, no local install, and no company/university email required.

Read `docs/simulator_notes.md` first if you're curious why this is the
recommended path instead of Icarus Verilog or Verilator.

## Step 1: Open EDA Playground

Go to https://www.edaplayground.com and sign in (a Google account is
enough - full account validation is not required for Riviera-PRO).

## Step 2: Configure the project

1. Language: select **SystemVerilog/Verilog**.
2. Tools & Simulators: select **Aldec Riviera Pro** (latest version
   listed).
3. Leave "Open EPWave after run" checked if you want to view
   waveforms in-browser after simulation.

## Step 3: Paste the DUT into the "Design" pane

Copy the entire contents of `rtl/SPI_Slave.v` into the right-hand
**Design** pane.

## Step 4: Paste the testbench into the "Testbench" pane

EDA Playground compiles the Testbench pane as one file, so combine
the following files **in this exact order** and paste them into the
left-hand **Testbench** pane:

1. `tb/spi_if.sv`
2. `assertions/spi_assertions.sv`
3. `tb/transaction.sv`
4. `tb/generator.sv`
5. `tb/scoreboard.sv`
6. `tb/driver.sv`
7. `tb/monitor.sv`
8. `tb/coverage.sv`
9. `tb/environment.sv`
10. `tb/test.sv`
11. `tb/top_tb.sv`

(Order matters for class dependencies - a class that uses another
class, like `driver` using `scoreboard`, must appear after it.)

Tip: for a repo you control, you can instead use EDA Playground's
"multiple files" feature (the `+` icon next to the pane) to upload
each file separately and skip the manual concatenation - just make
sure `top_tb.sv` is set as the top module.

## Step 5: Set the test to run

In the **Run Options** box (below the Testbench pane), add:

```
+TESTNAME=smoke_test
```

Change `smoke_test` to any of: `random_test`, `reset_test`,
`corner_test`, `back_to_back_test`, `pattern_test`.

## Step 6: Run

Click the green **Run** button. Output appears in the bottom console,
including every `$display`/`$error` message from the driver, monitor,
scoreboard, and assertions, followed by the final scoreboard/coverage
report.

## Step 7: View waveforms (optional)

If "Open EPWave after run" was checked, click **EPWave** to view the
waveform viewer directly in the browser - useful for debugging any
scoreboard or assertion failures.

## Step 8: Save and share (optional)

Click **Share** near the bottom to save a permanent link to your
session - handy for including in your GitHub README as a "try it
live" link, or for asking for help.

---

## Running locally instead (if you have a licensed simulator)

If you have VCS, Xcelium, Questa, or a local Riviera-PRO install:

```bash
make run SIM=vcs TEST=smoke_test
make run SIM=xcelium TEST=random_test
make run SIM=questa TEST=reset_test
make run SIM=riviera TEST=corner_test

# Run the full regression suite:
make regress SIM=vcs
```

See the `Makefile` for the exact compile/run commands used for each
simulator.
