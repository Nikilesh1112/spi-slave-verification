//=============================================================================
// File        : spi_if.sv
// Description : SystemVerilog interface that bundles together all signals
//               connecting the testbench to the SPI_Slave DUT.
//
//               Two clock domains exist on this DUT:
//                 - i_Clk      : the "system" clock (fast, FPGA-side clock)
//                 - i_SPI_Clk  : the SPI bus clock, driven by the SPI master
//                                (in our case, driven by the driver, since
//                                we are verifying a SPI SLAVE and there is
//                                no real master in the testbench)
//
//               Keeping all DUT signals in one interface avoids passing
//               a huge list of ports around every class, and lets us
//               attach protocol assertions directly to the interface.
//=============================================================================

interface spi_if (input logic i_Clk);

  // ---------------------------------------------------------------------
  // System clock domain signals
  // ---------------------------------------------------------------------
  logic        i_Rst_L;     // active-low system reset

  logic        o_RX_DV;     // pulses high for 1 clk when o_RX_Byte is valid
  logic [7:0]  o_RX_Byte;   // byte received from SPI master (on MOSI)

  logic        i_TX_DV;     // driver pulses this to load next TX byte
  logic [7:0]  i_TX_Byte;   // byte to be shifted out to SPI master (on MISO)

  // ---------------------------------------------------------------------
  // SPI bus signals (driven by our testbench, acting as the SPI Master)
  // ---------------------------------------------------------------------
  logic        i_SPI_Clk;   // SPI bus clock, driven by testbench (as master)
  logic        o_SPI_MISO;  // driven BY the DUT (slave), sampled by monitor
  logic        i_SPI_MOSI;  // driven by testbench (as master)
  logic        i_SPI_CS_n;  // active-low chip select, driven by testbench

  // ---------------------------------------------------------------------
  // Modport for the driver: drives SPI bus + system-side TX signals
  // ---------------------------------------------------------------------
  modport DRIVER (
    input i_Clk,
    output i_Rst_L,
    output i_SPI_Clk,
    output i_SPI_MOSI,
    output i_SPI_CS_n,
    output i_TX_DV,
    output i_TX_Byte,
    input  o_SPI_MISO,
    input  o_RX_DV,
    input  o_RX_Byte
  );

  // ---------------------------------------------------------------------
  // Modport for the monitor: only observes signals, drives nothing
  // ---------------------------------------------------------------------
  modport MONITOR (
    input i_Clk,
    input i_Rst_L,
    input i_SPI_Clk,
    input i_SPI_MOSI,
    input i_SPI_CS_n,
    input o_SPI_MISO,
    input o_RX_DV,
    input o_RX_Byte,
    input i_TX_DV,
    input i_TX_Byte
  );

endinterface : spi_if
