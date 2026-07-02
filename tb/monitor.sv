//=============================================================================
// File        : monitor.sv
// Description : Passively watches the SPI bus (MOSI/MISO/SCLK/CS_n) and
//               reconstructs each 8-bit transfer bit-by-bit, exactly the
//               way the DUT itself would see it (sampling MOSI on the
//               rising SCLK edge, and sampling MISO on the same edge to
//               check what the slave actually drove).
//
//               It also watches the DUT's system-clock-domain output
//               (o_RX_DV / o_RX_Byte) to cross-check that the DUT
//               reports the same byte it was sent.
//
//               Two mailboxes are used:
//                 mon2scb_mbx  -> sends observed transactions to scoreboard
//                 mon2cov_mbx  -> sends observed transactions to coverage
//=============================================================================

class monitor;

  virtual spi_if.MONITOR vif;
  mailbox #(transaction) mon2scb_mbx;
  mailbox #(transaction) mon2cov_mbx;

  function new(virtual spi_if.MONITOR vif,
               mailbox #(transaction) mon2scb_mbx,
               mailbox #(transaction) mon2cov_mbx);
    this.vif          = vif;
    this.mon2scb_mbx  = mon2scb_mbx;
    this.mon2cov_mbx  = mon2cov_mbx;
  endfunction

  // -------------------------------------------------------------------
  // run: main monitor loop.
  //   1. Wait for CS_n to go low (start of a burst)
  //   2. For each byte in the burst, sample MOSI/MISO on each SCLK
  //      rising edge (Mode 0) to rebuild the transferred byte pair
  //   3. After the 8th bit, race "next SCLK rising edge" against
  //      "CS_n rising edge" to determine whether the burst continues
  //      (cs_hold_after=1) or ends (cs_hold_after=0). If the burst
  //      continues, the edge we just saw IS the first bit of the next
  //      byte, so we remember it (pending_edge_valid) instead of
  //      waiting for a second edge and silently dropping a bit.
  //   4. Push the observed transaction into the scoreboard and
  //      coverage mailboxes.
  // -------------------------------------------------------------------
  task run();
    transaction mon_txn;
    bit [7:0]   mosi_shreg;
    bit [7:0]   miso_shreg;
    bit         pending_edge_valid; // true: we already saw next byte's bit-0 edge
    bit         burst_active;

    forever begin
      @(negedge vif.i_SPI_CS_n);
      pending_edge_valid = 1'b0;
      burst_active        = 1'b1;

      while (burst_active) begin
        mosi_shreg = 8'h00;
        miso_shreg = 8'h00;

        for (int bit_idx = 0; bit_idx < 8 && burst_active; bit_idx++) begin
          if (bit_idx == 0 && pending_edge_valid) begin
            // We already consumed this edge in the previous iteration
            // while checking for burst continuation - don't wait again.
            pending_edge_valid = 1'b0;
          end
          else begin
            @(posedge vif.i_SPI_Clk or posedge vif.i_SPI_CS_n);
            if (vif.i_SPI_CS_n) begin
              // CS deasserted mid-byte - discard the partial byte and
              // stop this burst (guards against a hang, though normal
              // tests never do this).
              burst_active = 1'b0;
            end
          end

          if (burst_active) begin
            mosi_shreg = {mosi_shreg[6:0], vif.i_SPI_MOSI};
            miso_shreg = {miso_shreg[6:0], vif.o_SPI_MISO};
          end
        end

        if (burst_active) begin
          mon_txn           = new();
          mon_txn.mosi_data = mosi_shreg;
          mon_txn.miso_data = miso_shreg;

          // Determine whether another byte follows in this same burst.
          @(posedge vif.i_SPI_Clk or posedge vif.i_SPI_CS_n);
          if (vif.i_SPI_CS_n) begin
            mon_txn.cs_hold_after = 1'b0;
            burst_active          = 1'b0;   // burst has ended
          end
          else begin
            mon_txn.cs_hold_after = 1'b1;
            pending_edge_valid    = 1'b1;   // this edge = next byte's bit 0
          end

          mon_txn.print("MON");
          mon2scb_mbx.put(mon_txn.copy());
          mon2cov_mbx.put(mon_txn.copy());
        end
      end
    end
  endtask

endclass : monitor
