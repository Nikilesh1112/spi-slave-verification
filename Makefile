#==============================================================================
# Makefile - SPI Slave Verification Environment
#
# IMPORTANT - READ THIS FIRST (see docs/simulator_notes.md for full details):
#
#   This testbench uses full SystemVerilog OOP: classes, mailboxes,
#   constrained-random (rand/constraint/randomize), and covergroups.
#
#   Free/open-source local tools were evaluated for this project and have
#   real limitations:
#     - Icarus Verilog (v12.0): does NOT support constraint blocks,
#       randomize(), parameterized mailboxes, or concurrent SVA
#       (assert property). Confirmed by direct testing.
#     - Verilator (v5.020, standard apt package): does NOT yet support
#       this class-based testbench style either. It CAN however lint
#       the synthesizable RTL cleanly, which is what the 'lint' target
#       below uses it for.
#
#   RECOMMENDED FREE WAY TO RUN THE FULL TESTBENCH:
#     Use EDA Playground (https://www.edaplayground.com) with the
#     "Aldec Riviera-PRO" simulator selected. It is free (Google login,
#     no company/university email needed) and fully supports classes,
#     mailboxes, constraints, and SVA. See docs/how_to_run.md for the
#     exact copy-paste steps.
#
#   If you have access to a commercial simulator (Synopsys VCS, Cadence
#   Xcelium, Siemens Questa, or a licensed Aldec Riviera-PRO) through
#   college or work, the 'run' target below will work locally - just
#   set SIM accordingly.
#==============================================================================

# Simulator selector: vcs | xcelium | questa | riviera
SIM ?= vcs

TESTNAME ?= smoke_test

RTL_DIR        = rtl
TB_DIR         = tb
ASSERT_DIR     = assertions
WAVE_DIR       = waves

RTL_FILES      = $(RTL_DIR)/SPI_Slave.v
TB_FILES       = $(TB_DIR)/spi_if.sv \
                  $(TB_DIR)/transaction.sv \
                  $(TB_DIR)/generator.sv \
                  $(TB_DIR)/scoreboard.sv \
                  $(TB_DIR)/driver.sv \
                  $(TB_DIR)/monitor.sv \
                  $(TB_DIR)/coverage.sv \
                  $(TB_DIR)/environment.sv \
                  $(TB_DIR)/test.sv \
                  $(TB_DIR)/top_tb.sv
ASSERT_FILES   = $(ASSERT_DIR)/spi_assertions.sv

ALL_FILES      = $(RTL_FILES) $(ASSERT_FILES) $(TB_FILES)

.PHONY: all lint run clean help

all: help

help:
	@echo "Targets:"
	@echo "  make lint                 - Lint the DUT RTL with Verilator (free, works locally)"
	@echo "  make run TEST=<name>      - Run one test with \$(SIM) (needs a full-SV simulator)"
	@echo "  make regress              - Run the full regression suite (see regression/run_regression.sh)"
	@echo "  make clean                - Remove simulation build artifacts"
	@echo ""
	@echo "Available TEST names: smoke_test, random_test, reset_test,"
	@echo "                       corner_test, back_to_back_test, pattern_test"
	@echo ""
	@echo "NOTE: 'make run' requires a simulator with full SystemVerilog class/"
	@echo "mailbox/constraint support (VCS, Xcelium, Questa, or Riviera-PRO)."
	@echo "Icarus Verilog and standard Verilator do NOT support this style of"
	@echo "testbench - see docs/simulator_notes.md. For a free option, use"
	@echo "EDA Playground with Aldec Riviera-PRO (docs/how_to_run.md)."

#------------------------------------------------------------------------
# lint: free, local, works out of the box with Verilator.
# Lints only the synthesizable DUT RTL (Verilator cannot elaborate the
# class-based testbench, so it is intentionally excluded here).
#------------------------------------------------------------------------
lint:
	verilator --lint-only $(RTL_FILES)

#------------------------------------------------------------------------
# run: generic target for a full SystemVerilog simulator.
# Adjust the command below for whichever simulator you have installed.
#------------------------------------------------------------------------
run:
ifeq ($(SIM),vcs)
	mkdir -p $(WAVE_DIR)
	vcs -sverilog -full64 -debug_access+all -timescale=1ns/1ps \
	    $(ALL_FILES) -o simv
	./simv +TESTNAME=$(TESTNAME)
else ifeq ($(SIM),xcelium)
	mkdir -p $(WAVE_DIR)
	xrun -sv -access +rwc -timescale 1ns/1ps \
	     $(ALL_FILES) +TESTNAME=$(TESTNAME)
else ifeq ($(SIM),questa)
	mkdir -p $(WAVE_DIR)
	vlog -sv $(ALL_FILES)
	vsim -c top_tb -do "run -all; quit" +TESTNAME=$(TESTNAME)
else ifeq ($(SIM),riviera)
	mkdir -p $(WAVE_DIR)
	vlib work
	vlog -sv2k12 $(ALL_FILES)
	vsim -c top_tb -do "run -all; quit" +TESTNAME=$(TESTNAME)
else
	@echo "Unknown SIM='$(SIM)'. Valid options: vcs, xcelium, questa, riviera"
	@echo "See docs/simulator_notes.md for free alternatives (EDA Playground)."
endif

#------------------------------------------------------------------------
# regress: runs every test in sequence, logging pass/fail per test.
#------------------------------------------------------------------------
regress:
	bash regression/run_regression.sh $(SIM)

#------------------------------------------------------------------------
# clean: remove build/sim artifacts
#------------------------------------------------------------------------
clean:
	rm -rf simv simv.daidir csrc *.log *.vcd *.vpd *.key \
	       work transcript vsim.wlf DVEfiles \
	       xcelium.d xrun.log xrun.history \
	       obj_dir $(WAVE_DIR)/*.vcd
	@echo "Cleaned build artifacts."
