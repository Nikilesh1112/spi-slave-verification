# Test Plan - SPI Slave

Each test lives as a task inside `tb/test.sv` and is selected in
`top_tb.sv` via the `+TESTNAME=<name>` plusarg. See `docs/how_to_run.md`
for exact run commands.

## Test List

| # | Test Name | File:Task | Purpose |
|---|---|---|---|
| 1 | `smoke_test` | `test.sv::smoke_test()` | Single byte transfer sanity check - the first test that should always be run |
| 2 | `random_test` | `test.sv::random_test()` | Constrained-random bursts (default 30 transactions) mixing single-byte and back-to-back transfers |
| 3 | `reset_test` | `test.sv::reset_test()` | Forces `i_Rst_L` low mid-transaction, verifies clean recovery afterward |
| 4 | `corner_test` | `test.sv::corner_test()` | Directed: 0x00, 0xFF, 0xAA, 0x55 data patterns |
| 5 | `back_to_back_test` | `test.sv::back_to_back_test()` | 8-byte continuous burst with CS_n held low throughout |
| 6 | `pattern_test` | `test.sv::pattern_test()` | Walking-1 and walking-0 bit patterns, catches bit-order bugs |

## Detailed Scenarios

### 1. smoke_test
- Reset the DUT.
- Send one byte (0xA5) on MOSI while preloading 0x3C for MISO.
- End the burst (CS_n deasserted).
- **Check**: scoreboard reports 0 failures; `o_RX_Byte` == 0xA5;
  MISO observed == 0x3C.

### 2. random_test
- Randomize 30 transactions (`transaction` class), each with random
  `mosi_data`, `miso_data`, and `cs_hold_after` (50/50 distribution
  between single-byte and back-to-back).
- **Check**: scoreboard reports 0 failures across all 30 transfers.

### 3. reset_test
- Start a transfer (0x5A on MOSI, 0xC3 preloaded for MISO).
- Partway through (after 3 SPI clock edges), force `i_Rst_L` low for
  5 system clock cycles, then release it.
- Bring CS_n back to idle.
- Send a completely fresh transfer (0x11 / 0x22) and confirm it
  works correctly.
- **Check**: no assertion errors during the forced reset; the
  post-reset transfer passes scoreboard checks cleanly.

### 4. corner_test
- Burst of 4 bytes, CS_n held low between the first three:
  - 0x00 / 0x00 (all zeros)
  - 0xFF / 0xFF (all ones)
  - 0xAA / 0x55 (alternating, starting with 1)
  - 0x55 / 0xAA (alternating, starting with 0) - ends burst
- **Check**: all 4 transfers pass scoreboard checks; functional
  coverage bins `zero`, `all_ones`, `alt_pattern` get hit.

### 5. back_to_back_test
- 8 bytes transferred in one continuous CS_n-low burst, with
  incrementing MOSI data (0,1,2...7) and decrementing MISO data.
- **Check**: all 8 transfers pass; `cp_cs_hold::back_to_back` coverage
  bin is heavily exercised; confirms DUT does not require CS_n toggle
  between bytes.

### 6. pattern_test
- 8 "walking 1" transfers (0x01, 0x02, 0x04, ... 0x80 on MOSI) held
  back-to-back.
- 8 "walking 0" transfers (bitwise inverse) held back-to-back, last
  one ends the burst.
- **Check**: catches any bit-reversal or off-by-one shift register
  bug in either the DUT or the testbench's own bit-banging logic,
  since walking patterns make ordering mistakes immediately visible
  in waveforms.

## Regression

`regression/run_regression.sh` runs all six tests in sequence against
a chosen simulator, logs each run to `regression/results/<test>.log`,
and prints a final pass/fail summary. See `Makefile` target `regress`.
