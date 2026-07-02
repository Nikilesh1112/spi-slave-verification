//=============================================================================
// File        : generator.sv
// Description : Generates transactions and sends them to the driver via a
//               mailbox. Supports:
//                 - fully random generation (num_txns randomized bytes)
//                 - directed generation (a specific queue of transactions,
//                   used for smoke test / corner cases / specific patterns)
//
//               Kept as a plain class (no uvm_sequence, no macros) so the
//               control flow is easy to read top-to-bottom.
//=============================================================================

class generator;

  mailbox #(transaction) gen2drv_mbx;  // handle to driver's inbox
  event                  drv_done;     // driver signals back when it is done
                                        // with all queued transactions (used
                                        // by the test to know when to finish)

  int num_txns = 10;   // number of random transactions to generate

  function new(mailbox #(transaction) gen2drv_mbx, event drv_done);
    this.gen2drv_mbx = gen2drv_mbx;
    this.drv_done    = drv_done;
  endfunction

  // -------------------------------------------------------------------
  // run_random: generate 'num_txns' fully randomized transactions
  // -------------------------------------------------------------------
  task run_random();
    transaction txn;
    for (int i = 0; i < num_txns; i++) begin
      txn = new();
      if (!txn.randomize()) begin
        $error("[GENERATOR] Randomization failed for txn %0d", i);
      end
      // Last transaction in the burst should always end the CS cycle,
      // otherwise the run would never deassert CS_n.
      if (i == num_txns - 1) txn.cs_hold_after = 1'b0;

      txn.print("GEN");
      gen2drv_mbx.put(txn);
    end
  endtask

  // -------------------------------------------------------------------
  // run_directed: send a pre-built queue of transactions (used by
  // smoke test, corner-case test, data-pattern test, etc.)
  // -------------------------------------------------------------------
  task run_directed(transaction txn_q[$]);
    foreach (txn_q[i]) begin
      txn_q[i].print("GEN-DIR");
      gen2drv_mbx.put(txn_q[i]);
    end
  endtask

endclass : generator
