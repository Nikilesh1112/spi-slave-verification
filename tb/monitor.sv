//=============================================================================
// File        : monitor.sv
// Description : Passively watches the SPI bus (MOSI/MISO/SCLK/CS_n) and
//               reconstructs each 8-bit transfer bit-by-bit.
//
//               FINAL TIMING NOTE (root-caused after debugging a shifted
//               MISO bug, then a shifted MOSI bug caused by an earlier
//               fix attempt): MOSI and MISO are NOT stable at the same
//               instant, so they cannot be safely sampled on the same
//               clock edge. Each is sampled on the edge where the DUT
//               itself guarantees a settled, race-free value:
//
//               - MOSI is sampled on the RISING edge of i_SPI_Clk. This
//                 is exactly the edge the DUT's own RX shift register
//                 uses to sample MOSI, and the driver (acting as SPI
//                 master) never changes MOSI at this instant - it only
//                 changes MOSI right after the FALLING edge - so there
//                 is no race here.
//
//               - MISO is sampled on the FALLING edge of i_SPI_Clk, one
//                 half period AFTER the rising edge that caused the DUT
//                 to update it. The DUT's TX shift register
//                 (r_SPI_MISO_Bit, r_TX_Bit_Count) updates via a
//                 non-blocking assignment inside
//                 "always @(posedge w_SPI_Clk or posedge i_SPI_CS_n)".
//                 Sampling MISO on that SAME rising edge races that
//                 update (can read the pre-update value); sampling on
//                 the following falling edge gives the update a full
//                 half period to settle, so it is race-free.
//
//               Using the SAME edge for both signals was tried and
//               fails either way: posedge-for-both raced MISO's update
//               (0x3C observed as 0x1E); negedge-for-both raced MOSI's
//               next-bit setup, which lands in the same NBA flush as
//               the falling edge (0xA5 observed as 0x4B). Sampling each
//               signal on its own correct edge fixes both.
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
  //   2. For each byte, and for each of its 8 bits:
  //        a. wait for the RISING edge, sample MOSI (race-free there)
  //        b. wait for the following FALLING edge, sample MISO
  //           (race-free there, a half period after the DUT's update)
  //   3. After the 8th bit, race "next SCLK rising edge" (next byte's
  //      bit-0 posedge) against "CS_n rising edge" to determine whether
  //      the burst continues (cs_hold_after=1) or ends (cs_hold_after=0).
  //      If it continues, the posedge we just saw for the lookahead IS
  //      the next byte's bit-0 rising edge, so we remember it
  //      (pending_posedge_valid) instead of waiting for a second rising
  //      edge and silently dropping a bit - we still sample MOSI from
  //      it normally once the next byte's loop reaches bit_idx 0.
  //   4. Push the observed transaction into the scoreboard and
  //      coverage mailboxes.
  // -------------------------------------------------------------------
  task run();
    transaction mon_txn;
    bit [7:0]   mosi_shreg;
    bit [7:0]   miso_shreg;
    bit         pending_posedge_valid; // true: next byte's bit-0 rising
                                        // edge was already seen during
                                        // the previous byte's lookahead
    bit         burst_active;

    forever begin
      @(negedge vif.i_SPI_CS_n);
      pending_posedge_valid = 1'b0;
      burst_active           = 1'b1;

      while (burst_active) begin
        mosi_shreg = 8'h00;
        miso_shreg = 8'h00;

        for (int bit_idx = 0; bit_idx < 8 && burst_active; bit_idx++) begin
          // ---- Step 1: rising edge -> sample MOSI ----
          if (bit_idx == 0 && pending_posedge_valid) begin
            // Already consumed this rising edge during the previous
            // byte's burst-continuation lookahead - don't wait again.
            pending_posedge_valid = 1'b0;
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

            // ---- Step 2: following falling edge -> sample MISO ----
            @(negedge vif.i_SPI_Clk or posedge vif.i_SPI_CS_n);
            if (vif.i_SPI_CS_n) begin
              burst_active = 1'b0;
            end
            else begin
              miso_shreg = {miso_shreg[6:0], vif.o_SPI_MISO};
            end
          end
        end

        if (burst_active) begin
          mon_txn           = new();
          mon_txn.mosi_data = mosi_shreg;
          mon_txn.miso_data = miso_shreg;

          // Determine whether another byte follows in this same burst:
          // race the next rising edge (next byte's bit 0) against CS_n
          // rising (end of burst).
          @(posedge vif.i_SPI_Clk or posedge vif.i_SPI_CS_n);
          if (vif.i_SPI_CS_n) begin
            mon_txn.cs_hold_after = 1'b0;
            burst_active          = 1'b0;   // burst has ended
          end
          else begin
            mon_txn.cs_hold_after = 1'b1;
            pending_posedge_valid = 1'b1;   // this edge = next byte's bit 0
          end

          mon_txn.print("MON");
          mon2scb_mbx.put(mon_txn.copy());
          mon2cov_mbx.put(mon_txn.copy());
        end
      end
    end
  endtask

endclass : monitor   
