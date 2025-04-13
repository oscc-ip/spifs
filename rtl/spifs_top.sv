// Copyright (c) 2023-2025 Yuchi Miao <miaoyuchi@ict.ac.cn>
// spifs is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "register.sv"
`include "spifs_define.svh"

module spi_top (
    input  logic                  pclk_i,
    input  logic                  presetn_i,
    input  logic [           4:0] paddr_i,
    input  logic [          31:0] pwdata_i,
    output logic [          31:0] prdata_o,
    input  logic                  pwrite_i,
    input  logic                  psel_i,
    input  logic                  penable_i,
    output logic                  pready_o,
    output logic                  pslverr_o,
    input  logic                  div4_i,
    output logic [`SPIFS_SS_NB-1:0] ss_o,
    output logic                  sclk_o,
    output logic                  mosi_o,
    input  logic                  miso_i,
    output logic                  irq_o
);


  logic [`SPIFS_CTRL_BIT-1:0] s_ctrl_d, s_ctrl_q;
  logic [31:0] s_prdata_d, s_prdata_q;
  logic s_pready_d, s_pready_q;
  logic s_irq_d, s_irq_q;

  logic [                  31:0] s_wb_dat;
  logic                          s_cpol;
  logic [     `SPIFS_MAX_CH-1:0] s_rx;
  logic [  `SPIFS_DIV_LEN-1:0] s_divider;
  logic [        `SPIFS_SS_NB-1:0] s_ss;
  logic                          s_rx_negedge;
  logic                          s_tx_negedge;
  logic [`SPIFS_CH_LEN-1:0] s_char_len;
  logic                          s_go;
  logic                          s_lsb;
  logic                          s_ie;
  logic                          s_ass;
  logic                          s_rd_endian;
  logic                          s_spi_divider_sel;
  logic                          s_spi_ctrl_sel;
  logic [                   3:0] s_spi_tx_sel;
  logic                          s_spi_ss_sel;
  logic                          s_tip;
  logic                          s_pos_edge;
  logic                          s_neg_edge;
  logic                          s_last_bit;

  assign prdata_o          = s_prdata_q;
  assign pready_o          = s_pready_q;
  assign pslverr_o         = 1'b0;
  assign irq_o             = s_irq_q;

  assign s_spi_divider_sel = psel_i & penable_i & (paddr_i[`SPIFS_OFS] == `SPIFS_DEVIDE);
  assign s_spi_ctrl_sel    = psel_i & penable_i & (paddr_i[`SPIFS_OFS] == `SPIFS_CTRL);
  assign s_spi_tx_sel[0]   = psel_i & penable_i & (paddr_i[`SPIFS_OFS] == `SPIFS_TX_0);
  assign s_spi_tx_sel[1]   = psel_i & penable_i & (paddr_i[`SPIFS_OFS] == `SPIFS_TX_1);
  assign s_spi_tx_sel[2]   = psel_i & penable_i & (paddr_i[`SPIFS_OFS] == `SPIFS_TX_2);
  assign s_spi_tx_sel[3]   = psel_i & penable_i & (paddr_i[`SPIFS_OFS] == `SPIFS_TX_3);
  assign s_spi_ss_sel      = psel_i & penable_i & (paddr_i[`SPIFS_OFS] == `SPIFS_SS);

  assign s_cpol            = ctrl[`SPIFS_CTRL_CPOL];
  assign s_ss              = ctrl[`SPIFS_CTRL_SS];
  assign s_divider         = div4_i ? 8'd1 : ctrl[`SPIFS_CTRL_DIV];
  assign s_rd_endian       = ctrl[`SPIFS_CTRL_RD_ENDIAN];
  assign s_rx_negedge      = ctrl[`SPIFS_CTRL_RX_NEGEDGE];
  assign s_tx_negedge      = ctrl[`SPIFS_CTRL_TX_NEGEDGE];
  assign s_go              = ctrl[`SPIFS_CTRL_GO];
  assign s_char_len        = ctrl[`SPIFS_CTRL_CHAR_LEN];
  assign s_lsb             = ctrl[`SPIFS_CTRL_LSB];
  assign s_ie              = ctrl[`SPIFS_CTRL_IE];
  assign s_ass             = ctrl[`SPIFS_CTRL_ASS];
  assign ss_o              = ~((s_ss &{`SPIFS_SS_NB{s_tip & s_ass}}) | (s_ss &{`SPIFS_SS_NB{!s_ass}}));


  always_comb begin
    s_wb_dat = '0;
    case (paddr_i[`SPIFS_OFS])
      `SPIFS_RX_0:   s_wb_dat = s_rx[31:0];
      `SPIFS_RX_1:   s_wb_dat = s_rx[63:32];
      `SPIFS_RX_2:   s_wb_dat = s_rx[95:64];
      `SPIFS_RX_3:   s_wb_dat = {{(128 - `SPIFS_MAX_CH) {1'b0}}, s_rx[`SPIFS_MAX_CH-1:96]};
      `SPIFS_CTRL:   s_wb_dat = {{(32 - `SPIFS_CTRL_BIT) {1'b0}}, ctrl};
      `SPIFS_DEVIDE: s_wb_dat = {{(32 - `SPIFS_DIV_LEN) {1'b0}}, s_divider};
      `SPIFS_SS:     s_wb_dat = {{(32 - `SPIFS_SS_NB) {1'b0}}, s_ss};
    endcase
  end

  always_comb begin
    s_prdata_d = s_prdata_q;
    if (s_rd_endian) s_prdata_d = {s_wb_dat[7:0], s_wb_dat[15:8], s_wb_dat[23:16], s_wb_dat[31:24]};
    else s_prdata_d = s_wb_dat;
  end
  dffr #(32) u_prdata_dffr (
      clk_i,
      rst_n_i,
      s_prdata_d,
      s_prdata_q
  );

  assign s_pready_d = psel_i & penable_i & ~pready_o;
  dffr #(1) u_pready_dffr (
      clk_i,
      rst_n_i,
      s_pready_d,
      s_pready_q
  );

  always_comb begin
    s_irq_d = s_irq_q;
    if (s_ie && s_tip && s_last_bit && s_pos_edge) s_irq_d = 1'b1;
    else if (pready_o) s_irq_d = 1'b0;
  end
  dffr #(1) u_irq_dffr (
      clk_i,
      rst_n_i,
      s_irq_d,
      s_irq_q
  );

  always_comb begin
    s_ctrl_d = s_ctrl_q;
    if (s_spi_ctrl_sel && pwrite_i && !s_tip) begin
      s_ctrl_d[`SPIFS_CTRL_BIT-1:0] = pwdata_i[`SPIFS_CTRL_BIT-1:0];
    end else if (s_tip && s_last_bit && s_pos_edge) s_ctrl_d[`SPIFS_CTRL_GO] = 1'b0;
  end
  dffr #(`SPIFS_CTRL_BIT) u_ctrl_dffr (
      clk_i,
      rst_n_i,
      s_ctrl_d,
      s_ctrl_q
  );


  spifs_clkgen u_spifs_clkgen (
      .clk_i     (pclk_i),
      .rst_n_i   (presetn_i),
      .ena_i     (s_tip),
      .go_i      (s_go),
      .last_clk_i(s_last_bit),
      .div_i     (s_divider),
      .spi_clk_o (sclk_o),
      .spi_pos_o (s_pos_edge),
      .spi_neg_o (s_neg_edge)
  );

  spifs_shift u_spifs_shift (
      .clk_i       (pclk_i),
      .rst_n_i     (presetn_i),
      .latch_i     (s_spi_tx_sel[3:0] & {4{pwrite_i}}),
      .byte_sel_i  (4'hF),
      .len_i       (s_char_len[`SPIFS_CH_LEN-1:0]),
      .lsb_i       (s_lsb),
      .go_i        (s_go),
      .pos_edge_i  (s_pos_edge),
      .neg_edge_i  (s_neg_edge),
      .rx_negedge_i(s_rx_negedge),
      .tx_negedge_i(s_tx_negedge),
      .tip_o       (s_tip),
      .last_o      (s_last_bit),
      .par_i       (pwdata_i),
      .par_o       (s_rx),
      .spi_clk_i   (sclk_o),
      .spi_in_i    (miso_i),
      .spi_out_o   (mosi_o)
  );
endmodule

