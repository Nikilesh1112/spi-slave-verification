#!/usr/bin/env bash
#==============================================================================
# run_regression.sh - Runs every test in the suite against a chosen
# simulator and prints a final PASS/FAIL summary.
#
# Usage:
#   bash regression/run_regression.sh <sim>
#   e.g. bash regression/run_regression.sh vcs
#
# NOTE: This requires a simulator with full SystemVerilog class/mailbox/
# constraint support (VCS, Xcelium, Questa, Riviera-PRO). It will NOT
# work with Icarus Verilog or standard Verilator - see
# docs/simulator_notes.md for why, and docs/how_to_run.md for the free
# EDA Playground workflow to run these tests interactively instead.
#==============================================================================

set -u

SIM="${1:-vcs}"
TESTS=("smoke_test" "random_test" "reset_test" "corner_test" "back_to_back_test" "pattern_test")

RESULTS_DIR="regression/results"
mkdir -p "$RESULTS_DIR"

PASS_COUNT=0
FAIL_COUNT=0

echo "========================================================="
echo " SPI SLAVE REGRESSION - simulator: $SIM"
echo "========================================================="

for TEST in "${TESTS[@]}"; do
  LOGFILE="$RESULTS_DIR/${TEST}.log"
  echo ""
  echo "---- Running $TEST ----"

  make run SIM="$SIM" TEST="$TEST" > "$LOGFILE" 2>&1

  if grep -q "RESULT       : TEST PASSED" "$LOGFILE" && ! grep -q "TEST FAILED" "$LOGFILE"; then
    echo "  [PASS] $TEST   (log: $LOGFILE)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $TEST   (log: $LOGFILE)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo ""
echo "========================================================="
echo " REGRESSION SUMMARY"
echo "   Total tests : ${#TESTS[@]}"
echo "   Passed      : $PASS_COUNT"
echo "   Failed      : $FAIL_COUNT"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "   RESULT      : ALL TESTS PASSED"
else
  echo "   RESULT      : REGRESSION FAILED"
fi
echo "========================================================="

exit $FAIL_COUNT
