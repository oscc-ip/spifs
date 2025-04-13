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

module spifs_shift (
    input  logic                          clk_i,
    input  logic                          rst_n_i,
    input  logic [                   3:0] latch_i,
    input  logic [                   3:0] byte_sel_i,
    input  logic [`SPIFS_CH_LEN-1:0] len_i,
    input  logic                          lsb_i,
    input  logic                          go_i,
    input  logic                          pos_edge_i,
    input  logic                          neg_edge_i,
    input  logic                          rx_negedge_i,
    input  logic                          tx_negedge_i,
    output logic                          tip_o,
    output logic                          last_o,
    input  logic [                  31:0] par_i,
    output logic [     `SPIFS_MAX_CH-1:0] par_o,
    input  logic                          spi_clk_i,
    input  logic                          spi_in_i,
    output logic                          spi_out_o
);

  logic s_spi_out_d, s_spi_out_q;
  logic s_tip_d, s_tip_q;
  logic [`SPIFS_CH_LEN:0] s_cnt_d, s_cnt_q;
  logic [`SPIFS_MAX_CH-1:0] s_data_d, s_data_q;

  logic [`SPIFS_CH_LEN:0] s_tx_bit_pos, s_rx_bit_pos;
  logic [`SPIFS_CH_LEN:0] s_tx_bit_pos_tmp;
  logic s_tx_clk, s_rx_clk;


  assign tip_o = s_tip_q;
  assign last_o = !(|s_cnt_q);
  assign par_o = s_data_q;
  assign spi_out_o = s_spi_out_q;

  assign s_rx_clk = (rx_negedge_i ? neg_edge_i : pos_edge_i) && (!last_o || spi_clk_i);
  assign s_tx_clk = (tx_negedge_i ? neg_edge_i : pos_edge_i) && !last_o;
  assign s_tx_bit_pos = lsb_i ? {!(|len_i), len_i} - s_cnt_q : s_cnt_q - {{`SPIFS_CH_LEN{1'b0}}, 1'b1};
  assign s_rx_bit_pos = lsb_i ? {!(|len_i), len_i} - (rx_negedge_i ? s_cnt_q + {{`SPIFS_CH_LEN{1'b0}},1'b1} : s_cnt_q) :
                            (rx_negedge_i ? s_cnt_q : s_cnt_q - {{`SPIFS_CH_LEN{1'b0}},1'b1});


  always_comb begin
    s_cnt_d = s_cnt_q;
    if (tip_o) s_cnt_d = pos_edge_i ? (s_cnt_q - {{`SPIFS_CH_LEN{1'b0}}, 1'b1}) : s_cnt_q;
    else s_cnt_d = !(|len_i) ? {1'b1, {`SPIFS_CH_LEN{1'b0}}} : {1'b0, len_i};
  end
  dffr #(`SPIFS_CH_LEN + 1) u_cnt_dffr (
      clk_i,
      rst_n_i,
      s_cnt_d,
      s_cnt_q
  );


  always_comb begin
    s_tip_d = s_tip_q;
    if (go_i && ~tip_o) s_tip_d = 1'b1;
    else if (tip_o && last_o && pos_edge_i) s_tip_d = 1'b0;
  end
  dffr #(1) u_tip_dffr (
      clk_i,
      rst_n_i,
      s_tip_d,
      s_tip_q
  );


  assign s_spi_out_d = (s_tx_clk || !tip_o) ? s_data_q[s_tx_bit_pos[`SPIFS_CH_LEN-1:0]] : spi_out_o;
  dffr #(1) u_spi_out_dffr (
      clk_i,
      rst_n_i,
      s_spi_out_d,
      s_spi_out_q
  );


  always_comb begin
    s_data_d = s_data_q;
    if (latch_i[0] && !tip_o) begin
      if (byte_sel_i[3]) s_data_d[31:24] = par_i[31:24];
      if (byte_sel_i[2]) s_data_d[23:16] = par_i[23:16];
      if (byte_sel_i[1]) s_data_d[15:8] = par_i[15:8];
      if (byte_sel_i[0]) s_data_d[7:0] = par_i[7:0];
    end else if (latch_i[1] && !tip_o) begin
      if (byte_sel_i[3]) s_data_d[63:56] = par_i[31:24];
      if (byte_sel_i[2]) s_data_d[55:48] = par_i[23:16];
      if (byte_sel_i[1]) s_data_d[47:40] = par_i[15:8];
      if (byte_sel_i[0]) s_data_d[39:32] = par_i[7:0];
    end else if (latch_i[2] && !tip_o) begin
      if (byte_sel_i[3]) s_data_d[95:88] = par_i[31:24];
      if (byte_sel_i[2]) s_data_d[87:80] = par_i[23:16];
      if (byte_sel_i[1]) s_data_d[79:72] = par_i[15:8];
      if (byte_sel_i[0]) s_data_d[71:64] = par_i[7:0];
    end else if (latch_i[3] && !tip_o) begin
      if (byte_sel_i[3]) s_data_d[127:120] = par_i[31:24];
      if (byte_sel_i[2]) s_data_d[119:112] = par_i[23:16];
      if (byte_sel_i[1]) s_data_d[111:104] = par_i[15:8];
      if (byte_sel_i[0]) s_data_d[103:96] = par_i[7:0];
    end else
      s_data_d[s_rx_bit_pos[`SPIFS_CH_LEN-1:0]] = s_rx_clk ? spi_in_i : s_data_q[s_rx_bit_pos[`SPIFS_CH_LEN-1:0]];
  end
  dffr #(`SPIFS_MAX_CH) u_data_dffr (
      clk_i,
      rst_n_i,
      s_data_d,
      s_data_q
  );

endmodule

