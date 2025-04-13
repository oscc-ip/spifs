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
`include "spifs_defines.svh"

module spifs_clkgen (
    input  logic                      clk_i,
    input  logic                      rst_n_i,
    input  logic                      ena_i,
    input  logic                      go_i,
    input  logic                      last_clk_i,
    input  logic [`SPIFS_DIV_LEN-1:0] div_i,
    output logic                      spi_clk_o,
    output logic                      spi_pos_o,
    output logic                      spi_neg_o
);

  logic [`SPIFS_DIV_LEN-1:0] s_cnt_d, s_cnt_q;
  logic s_cnt_zero;
  logic s_cnt_one;
  logic s_spi_clk_d, s_spi_clk_q;
  logic s_spi_pos_d, s_spi_pos_q;
  logic s_spi_neg_d, s_spi_neg_q;

  assign s_cnt_zero = s_cnt_q == '0;
  assign s_cnt_one  = s_cnt_q == {{(`SPIFS_DIV_LEN - 1) {1'b0}}, 1'b1};
  assign spi_clk_o  = s_spi_clk_q;
  assign spi_pos_o  = s_spi_pos_q;
  assign spi_neg_o  = s_spi_neg_q;

  always_comb begin
    s_cnt_d = s_cnt_q;
    if (!ena_i || s_cnt_zero) s_cnt_d = div_i;
    else s_cnt_d = s_cnt_q - {{(`SPIFS_DIV_LEN - 1) {1'b0}}, 1'b1};
  end
  dffrh #(`SPIFS_DIV_LEN) u_cnt_dfferh (
      clk_i,
      rst_n_i,
      s_cnt_d,
      s_cnt_q
  );

  assign s_spi_clk_d = (ena_i && s_cnt_zero && (!last_clk_i || spi_clk_o)) ? ~spi_clk_o : spi_clk_o;
  dffr #(1) u_spi_clk_dffr (
      clk_i,
      rst_n_i,
      s_spi_clk_d,
      s_spi_clk_q
  );

  assign s_spi_pos_d  = (ena_i && !spi_clk_o && s_cnt_one) || (!(|div_i) && spi_clk_o) || (!(|div_i) && go_i && !ena_i);
  dffr #(1) u_spi_pos_dffr (
      clk_i,
      rst_n_i,
      s_spi_pos_d,
      s_spi_pos_q
  );

  assign s_spi_neg_d = (ena_i && spi_clk_o && s_cnt_one) || (!(|div_i) && !spi_clk_o && ena_i);
  dffr #(1) u_spi_neg_dffr (
      clk_i,
      rst_n_i,
      s_spi_neg_d,
      s_spi_neg_q
  );

endmodule
