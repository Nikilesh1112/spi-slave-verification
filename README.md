# SPI Slave Verification Environment

A complete, non-UVM SystemVerilog verification environment for an
open-source SPI Slave RTL design. Built as a portfolio project to
demonstrate Design Verification fundamentals: transaction-level
testbench architecture, constrained-random and directed testing,
functional coverage, and SystemVerilog Assertions (SVA).

> **Note on scope**: this project deliberately avoids UVM, the factory
> pattern, RAL, and complex macros. The goal is to demonstrate solid
> DV fundamentals with plain, readable SystemVerilog.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [DUT: Why This RTL Was Chosen](#dut-why-this-rtl-was-chosen)
3. [Architecture](#architecture)
4. [Directory Structure](#directory-structure)
5. [Verification Flow](#verification-flow)
6. [How to Run](#how-to-run)
7. [Waveforms](#waveforms)
8. [Assertions](#assertions)
9. [Functional Coverage](#functional-coverage)
10. [Test List](#test-list)
11. [Getting This Onto GitHub (Zero to Published, Step by Step)](#getting-this-onto-github-zero-to-published-step-by-step)
12. [Known Limitations](#known-limitations)
13. [Future Improvements](#future-improvements)
14. [Interview Questions This Project Prepares You For](#interview-questions-this-project-prepares-you-for)
15. [Learning Outcomes](#learning-outcomes)
16. [License](#license)

---

## Project Overview

This repository verifies a **SPI Slave** RTL module using a
self-checking, transaction-level SystemVerilog testbench. It follows
the classic generator -> driver -> DUT -> monitor -> scoreboard /
coverage pipeline, communicating via `mailbox`es, exactly the
underlying architecture that UVM itself is built on top of - just
without the UVM base classes.

**What's verified:**
- Correct byte reception (MOSI -> `o_RX_Byte`/`o_RX_DV`)
- Correct byte transmission (`i_TX_Byte`/`i_TX_DV` -> MISO)
- Multi-byte back-to-back transfers (CS_n held low across bytes)
- MISO tri-state behavior when not selected
- Clean recovery from reset at any point in a transaction
- Protocol-level timing rules via SVA

## DUT: Why This RTL Was Chosen

| | |
|---|---|
| **Repository** | https://github.com/nandland/spi-slave |
| **Author** | Russell Merrick (nandland) |
| **License** | MIT |
| **File used** | `Verilog/source/SPI_Slave.v` (copied unmodified into `rtl/SPI_Slave.v`, with an added attribution header comment only) |

**Why this RTL:**
- **Open source and properly licensed** (MIT) - safe to use in a
  public portfolio repository with clear attribution.
- **Small and focused** - a single, well-commented module implementing
  one clear function (SPI slave shift register + clock-domain
  crossing), not a large SoC subsystem. Realistic scope for a fresher
  project.
- **Well written** - clean separation between the SPI clock domain and
  the system clock domain, uses standard double-flop synchronization,
  and is a widely-used, respected reference design in the FPGA/HDL
  community (used in many university and industry tutorials).
- **Realistic** - has real verification-worthy complexity: two clock
  domains, tri-state logic, MSB-first shifting, and configurable SPI
  mode - enough to write a genuinely meaningful testbench around,
  without being so complex that a fresher couldn't explain every
  signal in an interview.

Full attribution and the original MIT license text are preserved in
`rtl/LICENSE_DUT.txt`.

## Architecture

See `docs/architecture.md` for the full ASCII block diagram and
verification flow diagram. Summary:

```
generator --[mailbox]--> driver --> DUT (SPI_Slave) --> monitor --[mailbox]--> scoreboard
                                          ^                              |
                                          |                              +--[mailbox]--> coverage
                                    spi_assertions.sv
                              (bound directly to interface, checks
                               protocol rules continuously)
```

All components are plain SystemVerilog classes, wired together in
`tb/environment.sv` and driven by `tb/test.sv`.

## Directory Structure

```
spi-slave-verification/
├── README.md                  <- you are here
├── LICENSE                    <- project license (MIT)
├── .gitignore
├── Makefile                   <- lint/run/regress/clean targets
├── rtl/
│   ├── SPI_Slave.v             <- DUT (unmodified, from nandland/spi-slave)
│   └── LICENSE_DUT.txt         <- original DUT license + attribution
├── tb/
│   ├── spi_if.sv                <- interface + modports
│   ├── transaction.sv           <- randomizable transaction class
│   ├── generator.sv              <- stimulus generation
│   ├── driver.sv                  <- drives the SPI bus
│   ├── monitor.sv                  <- observes the SPI bus
│   ├── scoreboard.sv                <- checks DUT behavior
│   ├── coverage.sv                   <- functional coverage
│   ├── environment.sv                 <- wires everything together
│   ├── test.sv                         <- all test scenarios
│   └── top_tb.sv                        <- top-level TB module
├── assertions/
│   └── spi_assertions.sv        <- protocol-level SVA
├── docs/
│   ├── verification_plan.md
│   ├── architecture.md          <- includes ASCII diagrams
│   ├── test_plan.md
│   ├── simulator_notes.md       <- honest free-tool compatibility notes
│   ├── how_to_run.md            <- EDA Playground step-by-step guide
│   ├── known_limitations.md
│   └── future_scope.md
├── scripts/
│   └── concat_tb_for_eda_playground.sh
├── regression/
│   └── run_regression.sh
└── waves/                      <- VCD waveform dumps land here
```

## Verification Flow

1. `top_tb.sv` generates the system clock, instantiates the interface,
   DUT, and assertions module, and dumps waveforms.
2. Based on a `+TESTNAME` plusarg, `tb/test.sv` runs one of six test
   scenarios (see [Test List](#test-list)).
3. Each test resets the DUT, starts the environment's always-running
   components (driver, monitor, scoreboard, coverage) via `fork...join_none`,
   then feeds the generator either random or directed transactions.
4. The driver bit-bangs the SPI bus (acting as the SPI master) in Mode
   0 timing, while the monitor independently reconstructs each
   transfer straight off the bus.
5. The scoreboard checks two independent data paths (RX: MOSI ->
   `o_RX_Byte`; TX: preloaded `i_TX_Byte` -> observed MISO), and SVA
   assertions continuously check protocol timing rules.
6. Coverage samples every observed transaction plus reset/clock
   activity.
7. At the end of the test, the scoreboard and coverage print a final
   pass/fail and coverage-percentage report.

## How to Run

**Important:** this testbench uses SystemVerilog classes, mailboxes,
constrained-random, and SVA - features that Icarus Verilog and the
standard Verilator release do not fully support (verified by direct
testing - see `docs/simulator_notes.md`).

**Recommended free option:** EDA Playground with Aldec Riviera-PRO.
Full step-by-step instructions (with exact copy-paste steps) are in
**`docs/how_to_run.md`**. Short version:

1. Go to https://www.edaplayground.com, sign in with Google.
2. Language: SystemVerilog/Verilog. Simulator: Aldec Riviera Pro.
3. Paste `rtl/SPI_Slave.v` into the Design pane.
4. Run `bash scripts/concat_tb_for_eda_playground.sh` locally, then
   paste the generated `scripts/combined_tb.sv` into the Testbench pane.
5. Add `+TESTNAME=smoke_test` (or another test name) to Run Options.
6. Click Run.

**If you have a licensed simulator** (VCS, Xcelium, Questa, or local
Riviera-PRO):

```bash
make run SIM=vcs TEST=smoke_test
make regress SIM=vcs          # runs the full regression suite
```

**Free and works locally out of the box:**

```bash
make lint                      # lints the DUT RTL with Verilator
```

## Waveforms

`top_tb.sv` dumps a VCD file to `waves/spi_slave_tb.vcd` on every run
(`$dumpfile` / `$dumpvars`). Open it with GTKWave (free) or, if
running on EDA Playground, use the built-in EPWave viewer directly in
the browser (see `docs/how_to_run.md`, Step 7).

Recommended signals to add to a waveform view for debugging:
`i_SPI_Clk`, `i_SPI_MOSI`, `o_SPI_MISO`, `i_SPI_CS_n`, `o_RX_DV`,
`o_RX_Byte`, `i_TX_DV`, `i_TX_Byte`.

## Assertions

Six SVA checks in `assertions/spi_assertions.sv`, bound directly to
the interface signals (independent of the scoreboard):

| ID | Checks |
|---|---|
| A1 | `o_RX_DV` is exactly one clock cycle wide |
| A2 | `o_RX_DV` never asserts while in reset |
| A3 | `o_SPI_MISO` is high-Z whenever `i_SPI_CS_n` is high |
| A4 | `i_SPI_MOSI` does not glitch while `i_SPI_Clk` is high |
| A5 | `i_SPI_CS_n` stays low for at least one SPI clock edge once asserted |
| A6 | `o_RX_DV` is never asserted without a preceding CS_n-low transfer |

## Functional Coverage

Defined in `tb/coverage.sv`, three covergroups:

- **`cg_transaction`**: MOSI/MISO data value bins (zero, all-ones,
  alternating pattern, low/mid/high ranges) crossed with single-byte
  vs. back-to-back CS behavior.
- **`cg_reset`**: reset asserted / released.
- **`cg_spi_clk`**: SPI clock rising/falling edges seen while selected.

## Test List

| Test | Purpose |
|---|---|
| `smoke_test` | One byte transfer, basic sanity check |
| `random_test` | Constrained-random bursts (default 30 transactions) |
| `reset_test` | Reset asserted mid-transaction, checks recovery |
| `corner_test` | 0x00, 0xFF, alternating bit-pattern data |
| `back_to_back_test` | 8-byte continuous burst, CS_n held low throughout |
| `pattern_test` | Walking-1/walking-0 patterns, catches bit-order bugs |

Full details of each scenario are in `docs/test_plan.md`.

---

## Getting This Onto GitHub (Zero to Published, Step by Step)

This section assumes you know almost nothing about Git or GitHub yet.

### Step 1: Create a GitHub account (skip if you have one)

Go to https://github.com/join and follow the sign-up steps.

### Step 2: Create a new repository

1. Click the **+** icon in the top-right corner of GitHub, then
   **New repository**.
2. Repository name: `spi-slave-verification`
3. Description (optional): "Non-UVM SystemVerilog verification
   environment for an open-source SPI Slave"
4. Choose **Public** (so hiring managers can see it).
5. **Do not** check "Add a README" or "Add .gitignore" - this project
   already has both, and you'll be pushing them yourself.
6. Click **Create repository**. GitHub will show you a page with
   setup commands - keep that page open, you'll need the repository
   URL from it.

### Step 3: Install Git locally (skip if already installed)

- **Windows**: download and install from https://git-scm.com/download/win
- **macOS**: run `git --version` in Terminal - it will prompt you to
  install Xcode Command Line Tools if needed.
- **Linux**: `sudo apt-get install git` (Debian/Ubuntu) or your
  distro's equivalent.

Verify with:
```bash
git --version
```

### Step 4: Configure Git with your identity (one-time setup)

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```
(Use the same email as your GitHub account, or a GitHub-provided
no-reply email if you prefer to keep your email private.)

### Step 5: Get all the project files onto your computer

If you downloaded this project as a folder, just make sure it's saved
somewhere you can find it, e.g. `~/projects/spi-slave-verification/`.
Every file described in the [Directory Structure](#directory-structure)
section above should already be inside it, in the right subfolders -
nothing further to copy or create.

### Step 6: Initialize Git in the project folder

Open a terminal, navigate into the project folder, and run:

```bash
cd path/to/spi-slave-verification
git init
git add .
git commit -m "Initial commit: SPI Slave verification environment"
```

What each command does:
- `git init` - turns this folder into a Git repository.
- `git add .` - stages every file in the folder for commit.
- `git commit -m "..."` - saves a snapshot of all staged files with a
  message describing the change.

### Step 7: Connect your local folder to the GitHub repository

Copy the repository URL from the GitHub page you kept open in Step 2
(it looks like `https://github.com/<your-username>/spi-slave-verification.git`),
then run:

```bash
git remote add origin https://github.com/<your-username>/spi-slave-verification.git
git branch -M main
```

- `git remote add origin <url>` - tells Git where "origin" (your
  GitHub repository) is.
- `git branch -M main` - renames your current branch to `main`
  (GitHub's default branch name).

### Step 8: Push your code to GitHub

```bash
git push -u origin main
```

You'll be prompted to log in (GitHub now requires a Personal Access
Token instead of a password for command-line pushes - if prompted,
follow GitHub's on-screen instructions to create one at
https://github.com/settings/tokens, or use the GitHub Desktop app
instead of the command line if you prefer a GUI).

### Step 9: Verify everything is there

Refresh the repository page on GitHub. You should see all the folders
(`rtl/`, `tb/`, `assertions/`, `docs/`, `scripts/`, `regression/`,
`waves/`) and this `README.md` rendered automatically on the main page.

### Step 10 (optional but recommended): Add topics and a description

On your repository's GitHub page, click the gear icon next to "About"
(top right of the file list) and add:
- Description: "Non-UVM SystemVerilog DV environment for an SPI Slave"
- Topics: `systemverilog`, `design-verification`, `spi`, `testbench`,
  `hardware-verification`, `functional-coverage`, `sva`

This makes the repository more discoverable and immediately signals
to a hiring manager what they're looking at.

### Making future changes

Whenever you edit files later:

```bash
git add .
git commit -m "Describe what you changed"
git push
```

---

## Known Limitations

See `docs/known_limitations.md` for the full list. Highlights:
only SPI Mode 0 is verified; no multi-slave bus sharing test; no
formal verification or code/toggle coverage; free-tool simulation
requires EDA Playground or a licensed simulator (see
`docs/simulator_notes.md`).

## Future Improvements

See `docs/future_scope.md` for the full list. Highlights: verify all
4 SPI modes, add a coverage-driven regression loop, port this same
environment to UVM as a follow-up project, add CI linting.

## Interview Questions This Project Prepares You For

- Walk me through your testbench architecture - why generator/driver/
  monitor/scoreboard instead of one big block?
- Why did you choose mailboxes for inter-component communication?
  What problem do they solve?
- How does your scoreboard know what MISO value to expect?
- Explain the clock domain crossing in this DUT (SPI clock domain to
  system clock domain) - how did you verify it?
- Why are your assertions separate from your scoreboard? What does
  each catch that the other wouldn't?
- What's the difference between your functional coverage and code
  coverage? Which did you collect, and why?
- Why didn't you use UVM for this project? What would change if you
  did?
- What are SPI Modes 0-3, and why did you only verify Mode 0?
- If this design had a real bug, how would this environment help you
  localize it? Which components would report what?
- What did you learn about free EDA tooling from doing this project?

## Learning Outcomes

By building this project, you will have practiced:

- Reading and understanding third-party RTL as a black box
- Structuring a transaction-level, mailbox-based testbench from scratch
- Writing constrained-random stimulus with `rand`/`constraint`
- Writing a self-checking scoreboard with independent data paths
- Writing functional coverage with bins and crosses
- Writing protocol-level SVA assertions
- Understanding real SPI protocol timing (Mode 0, MSB-first shifting)
- Understanding clock domain crossing basics
- Navigating real-world free/open-source EDA tooling limitations
- Publishing a professional, well-documented project to GitHub

## License

This project (testbench, environment, assertions, documentation, and
scripts) is licensed under the MIT License - see `LICENSE`.

The DUT (`rtl/SPI_Slave.v`) is used unmodified from
[nandland/spi-slave](https://github.com/nandland/spi-slave), also
MIT licensed - see `rtl/LICENSE_DUT.txt` for the original license
text and attribution.
