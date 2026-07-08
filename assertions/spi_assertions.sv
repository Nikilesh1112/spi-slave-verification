//=============================================================================
// File        : spi_assertions.sv
// Description : Beginner/intermediate-level SystemVerilog Assertions (SVA)
//               for the SPI Slave DUT protocol. Bound into top_tb.sv as a
//               separate module (not embedded inside the DUT, since the
//               DUT is treated as black-box RTL from the design team).
//
//               Checks covered (see docs/verification_plan.md):
//                 A1 - o_RX_DV is exactly one clock cycle wide
//                 A2 - o_RX_DV is never asserted while in reset
//                 A3 - o_SPI_MISO is high-impedance while CS_n is high
//                 A4 - MOSI must be stable while SPI clock is high
//                      (Mode 0: data sampled on rising edge, so it must
//                      not change while SCLK is high)
//                 A5 - i_SPI_CS_n must not glitch (stay low) for at
//                      least one full SPI clock period once asserted
//                 A6 - after reset is released, o_RX_DV must not be
//                      asserted until a real transfer happens
//=============================================================================

module spi_assertions (
  input logic       i_Clk,
  input logic       i_Rst_L,
  input logic       i_SPI_Clk,
  input logic       i_SPI_MOSI,
  input logic       i_SPI_CS_n,
  input logic       o_SPI_MISO,
  input logic       o_RX_DV,
  input logic [7:0] o_RX_Byte
);

  // -------------------------------------------------------------------
  // A1: o_RX_DV must be exactly 1 clock cycle wide (pulses high for
  // one i_Clk period, then must go back low on the very next edge)
  // -------------------------------------------------------------------
  property p_rx_dv_one_cycle_pulse;
    @(posedge i_Clk) disable iff (!i_Rst_L)
      o_RX_DV |=> !o_RX_DV;
  endproperty

  a_rx_dv_one_cycle_pulse : assert property (p_rx_dv_one_cycle_pulse)
    else $error("[ASSERT] A1 FAILED: o_RX_DV stayed high for more than 1 cycle at time %0t", $time);

  // -------------------------------------------------------------------
  // A2: o_RX_DV must never be asserted while the DUT is held in reset
  // -------------------------------------------------------------------
  property p_no_rx_dv_during_reset;
    @(posedge i_Clk)
      (!i_Rst_L) |-> !o_RX_DV;
  endproperty

  a_no_rx_dv_during_reset : assert property (p_no_rx_dv_during_reset)
    else $error("[ASSERT] A2 FAILED: o_RX_DV asserted while i_Rst_L is low at time %0t", $time);

  // -------------------------------------------------------------------
  // A3: o_SPI_MISO must be high-impedance ('z') whenever CS_n is high
  // (deasserted), so multiple slaves can safely share the MISO line.
  // -------------------------------------------------------------------
  property p_miso_tristate_when_cs_high;
    @(posedge i_Clk)
      (i_SPI_CS_n) |-> (o_SPI_MISO === 1'bz);
  endproperty

  a_miso_tristate_when_cs_high : assert property (p_miso_tristate_when_cs_high)
    else $error("[ASSERT] A3 FAILED: o_SPI_MISO is not high-Z while i_SPI_CS_n is high at time %0t", $time);

  // -------------------------------------------------------------------
  // A4: In SPI Mode 0, MOSI must not change while SCLK is high, since
  // the DUT samples MOSI on the rising edge and expects the value held
  // through the entire high phase. Written as an immediate assertion
  // inside an always block (triggered only when MOSI actually toggles)
  // rather than a concurrent property, since this is easier for a
  // fresher to read and reason about, and avoids edge-alignment
  // subtleties of comparing samples across two different clock edges.
  // -------------------------------------------------------------------
  always @(i_SPI_MOSI) begin
    if (i_SPI_Clk === 1'b1 && i_SPI_CS_n === 1'b0) begin
      a_mosi_stable_while_sclk_high : assert (0)
        else $error("[ASSERT] A4 FAILED: i_SPI_MOSI changed while i_SPI_Clk was high at time %0t", $time);
    end
  end

  // -------------------------------------------------------------------
  // A5: Once CS_n is asserted (low), at least one SPI clock rising edge
  // must occur before CS_n goes back high - protects against a
  // testbench (or DUT) bug that pulses CS_n too briefly to be a legal
  // SPI transaction. Implemented with a simple edge counter rather than
  // a concurrent property, since the "wait for an edge on a different
  // clock before this clock's next event" check is awkward to express
  // cleanly as a property and much clearer as plain RTL-style code.
  // -------------------------------------------------------------------
  int sclk_edge_count;

  always @(negedge i_SPI_CS_n) begin
    sclk_edge_count <= 0;   // new burst starting, reset counter
  end

  always @(posedge i_SPI_Clk) begin
    if (!i_SPI_CS_n) sclk_edge_count <= sclk_edge_count + 1;
  end

  always @(posedge i_SPI_CS_n) begin
    if (i_Rst_L) begin
        a_cs_n_min_low_time : assert (sclk_edge_count >= 1)
            else
                $error("[ASSERT] A5 FAILED: i_SPI_CS_n was deasserted before any SPI clock edge occurred at time %0t", $time);
    end
end 

  // -------------------------------------------------------------------
  // A6: After reset is released, o_RX_DV must not be asserted unless
  // CS_n was low (a real transfer was happening) at some point in the
  // recent past. This is a simple sanity check that the DUT never
  // reports "data received" out of nowhere with no bus activity.
  // -------------------------------------------------------------------
  property p_rx_dv_needs_real_transfer;
    @(posedge i_Clk) disable iff (!i_Rst_L)
      o_RX_DV |-> $past(i_SPI_CS_n) === 1'b0;
  endproperty

  a_rx_dv_needs_real_transfer : assert property (p_rx_dv_needs_real_transfer)
    else $error("[ASSERT] A6 FAILED: o_RX_DV asserted without a preceding CS_n-low transfer at time %0t", $time);

endmodule : spi_assertions
