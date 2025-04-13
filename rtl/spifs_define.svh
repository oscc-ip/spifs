// Copyright (c) 2023-2025 Yuchi Miao <miaoyuchi@ict.ac.cn>
// spifs is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_SPIFS_DEF_SV
`define INC_SPIFS_DEF_SV

`define SPIFS_DIV_LEN     8
`define SPIFS_MAX_CH      128
`define SPIFS_CH_LEN      7
`define SPIFS_SS_NB       8

`define SPIFS_OFS         4:2
`define SPIFS_RX_0        0
`define SPIFS_RX_1        1
`define SPIFS_RX_2        2
`define SPIFS_RX_3        3
`define SPIFS_TX_0        0
`define SPIFS_TX_1        1
`define SPIFS_TX_2        2
`define SPIFS_TX_3        3
`define SPIFS_CTRL        4
`define SPIFS_DEVIDE      5
`define SPIFS_SS          6
`define SPIFS_CTRL_BIT    32

`define SPIFS_CTRL_SS         31:24
`define SPIFS_CTRL_DIV        23:16
`define SPIFS_CTRL_CPOL       15
`define SPIFS_CTRL_RD_ENDIAN  14
`define SPIFS_CTRL_ASS        13
`define SPIFS_CTRL_IE         12
`define SPIFS_CTRL_LSB        11
`define SPIFS_CTRL_TX_NEGEDGE 10
`define SPIFS_CTRL_RX_NEGEDGE 9
`define SPIFS_CTRL_GO         8
`define SPIFS_CTRL_CHAR_LEN   6:0

`define SPIFS_CTL_SS          32'h01000000
`define SPIFS_CTL_DIV         32'h00000000
`define SPIFS_CTL_RD_ENDIAN   32'h00004000
`define SPIFS_CTL_ASS         32'h00002000
`define SPIFS_CTL_IE          32'h00001000
`define SPIFS_CTL_TX_NEG      32'h00000400
`define SPIFS_CTL_GO          32'h00000100
`define SPIFS_CTL_CHAR_LEN    32'h00000040

`define SPIFS_ADDR_RXD0 5'h00
`define SPIFS_ADDR_RXD1 5'h04

`define SPIFS_ADDR_TXD0 5'h00
`define SPIFS_ADDR_TXD1 5'h04

`define SPIFS_ADDR_CTL 5'h10
`define SPIFS_ADDR_DIV 5'h14

`define SPIFS_CMD_IDLE     5'h0
`define SPIFS_CMD_SPI_CSR  5'h1
`define SPIFS_CMD_WR_TXD0  5'h2
`define SPIFS_CMD_WR_TXD1  5'h3
`define SPIFS_CMD_WR_CTL   5'h4
`define SPIFS_CMD_WAIT_IRQ 5'h5
`define SPIFS_CMD_RD_RXD0  5'h6

`define SPIFS_SPI_IDLE       5'h0
`define SPIFS_SPI_ENABLE     5'h1
`define SPIFS_SPI_WAIT_READY 5'h2

`define SPIFS_NSS_NUM    1
`define SPIFS_START      32'h4000_0000
`define SPIFS_END        32'h407F_FFFF

// io0(mosi)
// io1(miso)
// io2
// io3
interface spifs_if ();
  logic                      div4_i;
  logic                      spi_sck_o;
  logic [`SPIFS_NSS_NUM-1:0] spi_nss_o;
  logic                      spi_miso_i;
  logic                      spi_mosi_o;
  logic                      irq_o;

  modport dut(
      input  div4_i,
      output spi_sck_o,
      output spi_nss_o,
      input  spi_miso_i,
      output spi_mosi_o,
      output irq_o
  );

  // verilog_format: off
  modport tb(
      output div4_i,
      input  spi_sck_o,
      input  spi_nss_o,
      input  spi_io_en_o,
      output spi_miso_i,
      input  spi_mosi_o,
      input  irq_o
  );
  // verilog_format: on
endinterface

`endif
