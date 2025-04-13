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

module apb4_spifs (
    apb4_if.slave apb4,
    spifs_if.dut  spifs
);

  logic [31:0] s_paddr;
  logic        s_psel;
  logic        s_penable;
  logic        s_pwrite;
  logic [31:0] s_pwdata;
  logic [ 3:0] s_pwstrb;
  logic        s_pready;
  logic [31:0] s_prdata;
  logic        s_pslverr;
  logic        s_is_flash;

  logic [4:0] s_cmd_fsm_d, s_cmd_fsm_q;
  logic [4:0] s_spi_fsm_d, s_spi_fsm_q;
  logic [31:0] s_paddr_d, s_paddr_q;

  logic [31:0] s_paddr_in;
  logic        s_spi_fire;
  logic [31:0] s_spi_tx_data0;
  logic [31:0] s_spi_tx_data1;
  logic [31:0] s_spi_ctl_data;
  logic        s_spi_irq;
  logic        s_spi_start;
  logic [31:0] paddr_align;

  assign paddr_align = {apb4.paddr[31:2], 2'b00};
  assign s_paddr_d   = (apb4.psel && apb4.penable) ? paddr_align : s_paddr_q;
  dffr #(32) u_paddr_dffr (
      clk_i,
      rst_n_i,
      s_paddr_d,
      s_paddr_q
  );

  assign s_is_flash = s_paddr_in >= `SPIFS_START && s_paddr_in <= `SPIFS_END;
  assign s_paddr_in = paddr_align | s_paddr_q;

  assign apb4.pslverr = 1'b0;
  assign apb4.prdata = s_prdata;
  assign apb4.pready = s_cmd_fsm_q == `SPIFS_CMD_SPI_CSR && s_spi_fire ||
                       s_cmd_fsm_q == `SPIFS_CMD_RD_RXD0 && s_spi_fire;
  
  assign spifs.irq_o = s_cmd_fsm_q == `SPIFS_CMD_SPI_CSR ? s_spi_irq : 1'b0;
  // verilog_format: off
  assign s_psel    = s_spi_fsm_q == `SPIFS_SPI_WAIT_READY;
  assign s_pwstrb  = s_cmd_fsm_q == `SPIFS_CMD_SPI_CSR ? pwstrb : 4'hf;
  assign s_penable = s_spi_fsm_q == `SPIFS_SPI_ENABLE || s_spi_fsm_q == `SPIFS_SPI_WAIT_READY;
  assign s_pwrite  = s_cmd_fsm_q == `SPIFS_CMD_SPI_CSR ? apb4.pwrite : 
                     s_cmd_fsm_q == `SPIFS_CMD_RD_RXD0 ? 1'b0 : 1'b1;
  assign s_pwdata  = s_cmd_fsm_q == `SPIFS_CMD_SPI_CSR ? pwdata : 
                     s_cmd_fsm_q == `SPIFS_CMD_WR_TXD0 ? s_spi_tx_data0 : 
                     s_cmd_fsm_q == `SPIFS_CMD_WR_TXD1 ? s_spi_tx_data1 :
                     s_cmd_fsm_q == `SPIFS_CMD_WR_CTL  ? s_spi_ctl_data : 32'h0;
  assign s_paddr  =  s_cmd_fsm_q == `SPIFS_CMD_SPI_CSR ? paddr_align[4:0]:
                     s_cmd_fsm_q == `SPIFS_CMD_WR_TXD0 ? `SPIFS_ADDR_TXD0  :
                     s_cmd_fsm_q == `SPIFS_CMD_WR_TXD1 ? `SPIFS_ADDR_TXD1  :
                     s_cmd_fsm_q == `SPIFS_CMD_WR_CTL  ? `SPIFS_ADDR_CTL   :
                     s_cmd_fsm_q == `SPIFS_CMD_RD_RXD0 ? `SPIFS_ADDR_RXD0  : 5'h0;
  // verilog_format: on

  assign s_spi_tx_data0 = 32'h00000000;  //spi read 32bit data
  assign s_spi_tx_data1 = 32'h03000000 | s_paddr_in[23:0];  //addr and read cmd
  assign s_spi_ctl_data = `SPIFS_CTL_SS | `SPIFS_CTL_DIV | `SPIFS_CTL_RD_ENDIAN | `SPIFS_CTL_ASS | 
                          `SPIFS_CTL_IE | `SPIFS_CTL_TX_NEG | `SPIFS_CTL_GO | `SPIFS_CTL_CHAR_LEN;

  assign s_spi_fire = s_spi_fsm_q == `SPIFS_SPI_WAIT_READY && s_pready;
  assign s_spi_start = s_cmd_fsm_q != `SPIFS_CMD_IDLE && s_cmd_fsm_q != `SPIFS_CMD_WAIT_IRQ;


  always_comb begin
    s_cmd_fsm_d = s_cmd_fsm_q;
    case (s_cmd_fsm_q)
      `SPIFS_CMD_IDLE: begin
        if (apb4.psel && apb4.penable) begin
          if (s_is_flash && !apb4.pwrite)  //read only!!!
            s_cmd_fsm_d = `SPIFS_CMD_WR_TXD0;
          else s_cmd_fsm_d = `SPIFS_CMD_SPI_CSR;
        end else s_cmd_fsm_d = `SPIFS_CMD_IDLE;
      end
      `SPIFS_CMD_SPI_CSR: begin
        if (s_spi_fire) s_cmd_fsm_d = `SPIFS_CMD_IDLE;
        else s_cmd_fsm_d = `SPIFS_CMD_SPI_CSR;
      end
      `SPIFS_CMD_WR_TXD0: begin
        if (s_spi_fire) s_cmd_fsm_d = `SPIFS_CMD_WR_TXD1;
        else s_cmd_fsm_d = `SPIFS_CMD_WR_TXD0;
      end
      `SPIFS_CMD_WR_TXD1: begin
        if (s_spi_fire) s_cmd_fsm_d = `SPIFS_CMD_WR_CTL;
        else s_cmd_fsm_d = `SPIFS_CMD_WR_TXD1;
      end
      `SPIFS_CMD_WR_CTL: begin
        if (s_spi_fire) s_cmd_fsm_d = `SPIFS_CMD_WAIT_IRQ;
        else s_cmd_fsm_d = `SPIFS_CMD_WR_CTL;
      end
      `SPIFS_CMD_WAIT_IRQ: begin
        if (s_spi_irq) s_cmd_fsm_d = `SPIFS_CMD_RD_RXD0;
        else s_cmd_fsm_d = `SPIFS_CMD_WAIT_IRQ;
      end
      default: begin  //`SPIFS_CMD_RD_RXD0
        if (s_spi_fire) s_cmd_fsm_d = `SPIFS_CMD_IDLE;
        else s_cmd_fsm_d = `SPIFS_CMD_RD_RXD0;
      end
    endcase
  end
  dffr #(5) u_cmd_fsm_dffr (
      apb4.pclk,
      apb4.presetn,
      s_cmd_fsm_d,
      s_cmd_fsm_q
  );

  always_comb begin
    s_spi_fsm_d = s_spi_fsm_q;
    case (s_spi_fsm_q)
      `SPIFS_SPI_IDLE: begin
        if (s_spi_start) s_spi_fsm_d = `SPIFS_SPI_ENABLE;
        else s_spi_fsm_d = `SPIFS_SPI_IDLE;
      end
      `SPIFS_SPI_ENABLE: begin
        s_spi_fsm_d = `SPIFS_SPI_WAIT_READY;
      end
      default: begin  //SPIFS_SPI_WAIT_READY
        if (s_pready) s_spi_fsm_d = `SPIFS_SPI_IDLE;
        else s_spi_fsm_d = `SPIFS_SPI_WAIT_READY;
      end
    endcase
  end
  dffr #(5) u_spi_fsm_dffr (
      apb4.pclk,
      apb4.presetn,
      s_spi_fsm_d,
      s_spi_fsm_q
  );

  spifs_top u_spifs_top (
      .pclk_i   (apb4.pclk),
      .presetn_i(apb4.presetn),
      .paddr_i  (s_paddr[4:0]),
      .pwdata_i (s_pwdata),
      .prdata_o (s_prdata),
      .pwrite_i (s_pwrite),
      .psel_i   (s_psel),
      .penable_i(s_penable),
      .pready_o (s_pready),
      .pslverr_o(s_pslverr),
      .div4_i   (spifs.div4_i),
      .ss_o     (spifs.spi_nss_o),
      .sclk_o   (spifs.spi_sck_o),
      .mosi_o   (spifs.spi_mosi_o),
      .miso_i   (spifs.spi_miso_i),
      .irq_o    (s_spi_irq)
  );

endmodule
