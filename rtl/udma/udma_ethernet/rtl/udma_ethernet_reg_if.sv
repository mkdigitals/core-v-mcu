// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

///////////////////////////////////////////////////////////////////////////////
//
// Description: ETHERNET configuration interface
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Antonio Pullini (pullinia@iis.ee.ethz.ch)
// Edited By    : Mustafa Karadayi(PlanV    -   mustafa.karadayi@planv.tech)
///////////////////////////////////////////////////////////////////////////////

/* verilator lint_off REDEFMACRO */
`define ETH_REG_RX_SADDR_0  5'b00000 //BASEADDR+0x00
`define ETH_REG_RX_SADDR_1  5'b00001 //BASEADDR+0x04
`define ETH_REG_RX_SADDR_2  5'b00010 //BASEADDR+0x08
`define ETH_REG_RX_SADDR_3  5'b00011 //BASEADDR+0x0C
`define ETH_REG_RX_DESC_0   5'b00100 //BASEADDR+0x10
`define ETH_REG_RX_DESC_1   5'b00101 //BASEADDR+0x14
`define ETH_REG_RX_DESC_2   5'b00110 //BASEADDR+0x18
`define ETH_REG_RX_DESC_3   5'b00111 //BASEADDR+0x1C
`define ETH_REG_RX_CADDR    5'b01000 //BASEADDR+0x20
`define ETH_REG_RX_SIZE     5'b01001 //BASEADDR+0x24
`define ETH_REG_RX_CFG      5'b01010 //BASEADDR+0x28
`define ETH_REG_TX_SADDR    5'b01011 //BASEADDR+0x2C
`define ETH_REG_TX_SIZE     5'b01100 //BASEADDR+0x30
`define ETH_REG_TX_CFG      5'b01101 //BASEADDR+0x34
`define ETH_REG_STATUS      5'b01110 //BASEADDR+0x38
`define ETH_REG_ETH_SETUP   5'b01111 //BASEADDR+0x3C
`define ETH_REG_ERROR       5'b10000 //BASEADDR+0x40
`define ETH_REG_IRQ_EN      5'b10001 //BASEADDR+0x44
`define ETH_REG_RX_FCS      5'b10010 //BASEADDR+0x48
`define ETH_REG_TX_FCS      5'b10011 //BASEADDR+0x4C
/* verilator lint_on REDEFMACRO */

module udma_ethernet_reg_if #(
    parameter L2_AWIDTH_NOAL = 12,
    parameter TRANS_SIZE     = 16
) (
	input   logic                       clk_i,
	input   logic                       rstn_i,

	input   logic               [31:0]  cfg_data_i,
	input   logic               [4:0]   cfg_addr_i,
	input   logic                       cfg_valid_i,
	input   logic                       cfg_rwn_i,
	output  logic               [31:0]  cfg_data_o,
	output  logic                       cfg_ready_o,

    output  logic [L2_AWIDTH_NOAL-1:0]  cfg_rx_startaddr0_o,
    output  logic [L2_AWIDTH_NOAL-1:0]  cfg_rx_startaddr1_o,
    output  logic [L2_AWIDTH_NOAL-1:0]  cfg_rx_startaddr2_o,
    output  logic [L2_AWIDTH_NOAL-1:0]  cfg_rx_startaddr3_o,
    input   logic [L2_AWIDTH_NOAL-1:0]  cfg_rx_pointer_i,
    input   logic     [TRANS_SIZE-1:0]  cfg_rx_size_i,

    output  logic                       cfg_rx_continuous_o,
    output  logic                       cfg_rx_en_o,
    output  logic                       cfg_rx_clr_o,
    input   logic                       cfg_rx_en_i,
    input   logic                       cfg_rx_pending_i,
    input   logic [L2_AWIDTH_NOAL-1:0]  cfg_rx_curr_addr_i,
    input   logic     [TRANS_SIZE-1:0]  cfg_rx_bytes_left_i,

    output  logic [L2_AWIDTH_NOAL-1:0]  cfg_tx_startaddr_o,
    output  logic     [TRANS_SIZE-1:0]  cfg_tx_size_o,
    output  logic                       cfg_tx_continuous_o,
    output  logic                       cfg_tx_en_o,
    output  logic                       cfg_tx_clr_o,
    input   logic                       cfg_tx_en_i,
    input   logic                       cfg_tx_pending_i,
    input   logic [L2_AWIDTH_NOAL-1:0]  cfg_tx_curr_addr_i,
    input   logic     [TRANS_SIZE-1:0]  cfg_tx_bytes_left_i,

    input   logic               [7:0]   status_i,
    input   logic               [1:0]   speed_i,
    input   logic               [31:0]  rx_fcs_i,
    input   logic               [31:0]  tx_fcs_i,

    output  logic                       rx_irq_en_o,
    output  logic                       err_irq_en_o,
    output  logic                       en_rx_o,
    output  logic                       en_tx_o,
    input   logic                       tx_busy_i
);

    logic [L2_AWIDTH_NOAL-1:0] r_rx_startaddr0;
    logic [L2_AWIDTH_NOAL-1:0] r_rx_startaddr1;
    logic [L2_AWIDTH_NOAL-1:0] r_rx_startaddr2;
    logic [L2_AWIDTH_NOAL-1:0] r_rx_startaddr3;
    (* KEEP = "TRUE" *) logic [31:0]               r_rx_desc_0 = 'h0;
    (* KEEP = "TRUE" *) logic [31:0]               r_rx_desc_1 = 'h0;
    (* KEEP = "TRUE" *) logic [31:0]               r_rx_desc_2 = 'h0;
    (* KEEP = "TRUE" *) logic [31:0]               r_rx_desc_3 = 'h0;
    (* KEEP = "TRUE" *) logic [1:0] r_rx_pointer = 2'b11;                        
    (* KEEP = "TRUE" *) logic   [TRANS_SIZE-1 : 0] r_rx_size;
    logic                      r_rx_continuous;
    logic                      r_rx_en;
    logic                      r_rx_clr;

    logic [L2_AWIDTH_NOAL-1:0] r_tx_startaddr;
    logic   [TRANS_SIZE-1 : 0] r_tx_size;
    logic                      r_tx_continuous;
    logic                      r_tx_en;
    logic                      r_tx_clr;

    logic                [4:0] s_wr_addr;
    logic                [4:0] s_rd_addr;

    logic                      s_err_clr;

    logic                      r_err_tx_fifo_overflow;
    logic                      r_err_tx_fifo_bad_frame;
    logic                      r_err_rx_error_bad_frame;
    logic                      r_err_rx_error_bad_fcs;
    logic                      r_err_rx_fifo_overflow;
    logic                      r_err_rx_fifo_bad_frame;

    logic                      r_eth_err_irq_en;
    logic                      r_eth_rx_irq_en;
    logic                      r_eth_en_tx;
    logic                      r_eth_en_rx;

    assign s_wr_addr = (cfg_valid_i & ~cfg_rwn_i) ? cfg_addr_i : 5'h0;
    assign s_rd_addr = (cfg_valid_i &  cfg_rwn_i) ? cfg_addr_i : 5'h0;

    assign cfg_rx_startaddr0_o  = r_rx_startaddr0;
    assign cfg_rx_startaddr1_o  = r_rx_startaddr1;
    assign cfg_rx_startaddr2_o  = r_rx_startaddr2;
    assign cfg_rx_startaddr3_o  = r_rx_startaddr3;
    assign r_rx_size           = cfg_rx_size_i;
    assign cfg_rx_continuous_o = r_rx_continuous;
    assign cfg_rx_en_o         = r_rx_en;
    assign cfg_rx_clr_o        = r_rx_clr;

    assign cfg_tx_startaddr_o  = r_tx_startaddr;
    assign cfg_tx_size_o       = r_tx_size;
    assign cfg_tx_continuous_o = r_tx_continuous;
    assign cfg_tx_en_o         = r_tx_en;
    assign cfg_tx_clr_o        = r_tx_clr;

    assign en_tx_o         = r_eth_en_tx;
    assign en_rx_o         = r_eth_en_rx;
    
    assign rx_irq_en_o     = r_eth_rx_irq_en;
    assign err_irq_en_o    = r_eth_err_irq_en;

    always_ff @(posedge clk_i, negedge rstn_i)
    begin
        if(~rstn_i)
        begin
            // REGS
            r_rx_startaddr0             <=  'h0;
            r_rx_startaddr1             <=  'h0;
            r_rx_startaddr2             <=  'h0;
            r_rx_startaddr3             <=  'h0;
            r_rx_continuous             <=  'h0;
            r_rx_en                     <=  'h0;
            r_rx_clr                    <=  'h0;
            r_tx_startaddr              <=  'h0;
            r_tx_size                   <=  'h0;
            r_tx_continuous             <=  'h0;
            r_tx_en                     <=  'h0;
            r_tx_clr                    <=  'h0;
            r_err_tx_fifo_overflow      <=  'h0;
            r_err_tx_fifo_bad_frame     <=  'h0;
            r_err_rx_error_bad_frame    <=  'h0;
            r_err_rx_error_bad_fcs      <=  'h0;
            r_err_rx_fifo_overflow      <=  'h0;
            r_err_rx_fifo_bad_frame     <=  'h0;
            r_rx_desc_0                 <=  'h0;
            r_rx_desc_1                 <=  'h0;
            r_rx_desc_2                 <=  'h0;
            r_rx_desc_3                 <=  'h0;
        end
        else
        begin
            r_rx_en  <=  'h0;
            r_tx_en  <=  'h0;

            if(status_i[7])
                r_err_tx_fifo_overflow <= 1'b1;
            else if(s_err_clr)
                r_err_tx_fifo_overflow  <= 1'b0;

            if(status_i[6])
                r_err_tx_fifo_bad_frame <= 1'b1;
            else if(s_err_clr)
                r_err_tx_fifo_bad_frame  <= 1'b0;

            if(status_i[4])
                r_err_rx_error_bad_frame <= 1'b1;
            else if(s_err_clr)
                r_err_rx_error_bad_frame  <= 1'b0;

            if(status_i[3])
                r_err_rx_error_bad_fcs <= 1'b1;
            else if(s_err_clr)
                r_err_rx_error_bad_fcs  <= 1'b0;

            if(status_i[2])
                r_err_rx_fifo_overflow <= 1'b1;
            else if(s_err_clr)
                r_err_rx_fifo_overflow  <= 1'b0;

            if(status_i[1])
                r_err_rx_fifo_bad_frame <= 1'b1;
            else if(s_err_clr)
                r_err_rx_fifo_bad_frame  <= 1'b0;

            r_rx_pointer <= cfg_rx_pointer_i;
            
            if(r_rx_pointer != cfg_rx_pointer_i)
            begin
                case(cfg_rx_pointer_i)
                2'b00:
                begin
                    r_rx_desc_0[31] <= 1'b1;
                    r_rx_desc_0[(TRANS_SIZE-1):0] <= r_rx_size[(TRANS_SIZE-1):0];
                end
                2'b01:
                begin
                    r_rx_desc_1[31] <= 1'b1;
                    r_rx_desc_1[(TRANS_SIZE-1):0] <= r_rx_size[(TRANS_SIZE-1):0];
                end
                2'b10:
                begin
                    r_rx_desc_2[31] <= 1'b1;
                    r_rx_desc_2[(TRANS_SIZE-1):0] <= r_rx_size[(TRANS_SIZE-1):0];
                end
                2'b11:
                begin
                    r_rx_desc_3[31] <= 1'b1;
                    r_rx_desc_3[(TRANS_SIZE-1):0] <= r_rx_size[(TRANS_SIZE-1):0];
                end
                endcase;
            end

            if (cfg_valid_i & ~cfg_rwn_i)
            begin
                case (s_wr_addr)
                `ETH_REG_RX_SADDR_0:
                    r_rx_startaddr0    <= cfg_data_i[L2_AWIDTH_NOAL-1:0];
                `ETH_REG_RX_SADDR_1:
                    r_rx_startaddr1    <= cfg_data_i[L2_AWIDTH_NOAL-1:0];
                `ETH_REG_RX_SADDR_2:
                    r_rx_startaddr2    <= cfg_data_i[L2_AWIDTH_NOAL-1:0];
                `ETH_REG_RX_SADDR_3:
                    r_rx_startaddr3    <= cfg_data_i[L2_AWIDTH_NOAL-1:0];
                `ETH_REG_RX_DESC_0:
                    r_rx_desc_0[31]    <=  cfg_data_i[31];
                `ETH_REG_RX_DESC_1:
                    r_rx_desc_1[31]    <=  cfg_data_i[31];
                `ETH_REG_RX_DESC_2:
                    r_rx_desc_2[31]    <=  cfg_data_i[31];
                `ETH_REG_RX_DESC_3:
                    r_rx_desc_3[31]    <=  cfg_data_i[31];
                `ETH_REG_RX_CFG:
                begin
                    r_rx_clr           <= cfg_data_i[6];
                    r_rx_en            <= cfg_data_i[4];
                    r_rx_continuous   <= cfg_data_i[0];
                end
                `ETH_REG_TX_SADDR:
                    r_tx_startaddr    <= cfg_data_i[L2_AWIDTH_NOAL-1:0];
                `ETH_REG_TX_SIZE:
                    r_tx_size         <= cfg_data_i[TRANS_SIZE-1:0];
                `ETH_REG_TX_CFG:
                begin
                    r_tx_clr           <= cfg_data_i[6];
                    r_tx_en            <= cfg_data_i[4] & ~tx_busy_i;
                    r_tx_continuous   <= cfg_data_i[0];
                end

                `ETH_REG_ETH_SETUP:
                begin
                  r_eth_en_rx      <= cfg_data_i[9];
                  r_eth_en_tx      <= cfg_data_i[8];
                end
                `ETH_REG_IRQ_EN:
                  begin
                    r_eth_err_irq_en <= cfg_data_i[1];
                    r_eth_rx_irq_en  <= cfg_data_i[0];
                  end
                
                endcase
            end
        end
    end //always

    always_comb
    begin
        cfg_data_o = 32'h0;

        s_err_clr = 1'b0;

        case (s_rd_addr)
        `ETH_REG_RX_SADDR_0:
        begin    
            cfg_data_o[31 : L2_AWIDTH_NOAL] <= 0;
            cfg_data_o[L2_AWIDTH_NOAL-1:0] <= r_rx_startaddr0;
        end
        `ETH_REG_RX_SADDR_1:
        begin
            cfg_data_o[31 : L2_AWIDTH_NOAL] <= 0;
            cfg_data_o[L2_AWIDTH_NOAL-1:0] <= r_rx_startaddr1;
        end
        `ETH_REG_RX_SADDR_2:
        begin
            cfg_data_o[31 : L2_AWIDTH_NOAL] <= 0;
            cfg_data_o[L2_AWIDTH_NOAL-1:0] <= r_rx_startaddr2;
        end
        `ETH_REG_RX_SADDR_3:
        begin
            cfg_data_o[31 : L2_AWIDTH_NOAL] <= 0;
            cfg_data_o[L2_AWIDTH_NOAL-1:0] <= r_rx_startaddr3;
        end 
        `ETH_REG_RX_DESC_0:
            cfg_data_o <= r_rx_desc_0;
        `ETH_REG_RX_DESC_1:
            cfg_data_o <= r_rx_desc_1;
        `ETH_REG_RX_DESC_2:
            cfg_data_o <= r_rx_desc_2;
        `ETH_REG_RX_DESC_3:
            cfg_data_o <= r_rx_desc_3;
        `ETH_REG_RX_CADDR:
            cfg_data_o <= cfg_rx_curr_addr_i;
        `ETH_REG_RX_SIZE:
            cfg_data_o[TRANS_SIZE-1:0] <= cfg_rx_bytes_left_i;
        `ETH_REG_RX_CFG:
            cfg_data_o <= {26'h0,cfg_rx_pending_i,cfg_rx_en_i,3'h0,r_rx_continuous};
        `ETH_REG_TX_SADDR:
            cfg_data_o <= cfg_tx_curr_addr_i;
        `ETH_REG_TX_SIZE:
            cfg_data_o[TRANS_SIZE-1:0] = cfg_tx_bytes_left_i;
        `ETH_REG_TX_CFG:
            cfg_data_o <= {26'h0,cfg_tx_pending_i,cfg_tx_en_i,3'h0,r_tx_continuous};
        `ETH_REG_ETH_SETUP:
            cfg_data_o <= {22'h0, r_eth_en_rx, r_eth_en_tx, 8'h0};
        `ETH_REG_STATUS:
            cfg_data_o <= {21'h0,tx_busy_i ,speed_i[1:0], status_i[7:0]};
        `ETH_REG_ERROR:
         begin
            cfg_data_o = {26'h0,r_err_tx_fifo_overflow,
                                r_err_tx_fifo_bad_frame,
                                r_err_rx_error_bad_frame,
                                r_err_rx_error_bad_fcs,
                                r_err_rx_fifo_overflow,
                                r_err_rx_fifo_bad_frame};
            s_err_clr = 1'b1;
         end
        `ETH_REG_IRQ_EN:
            cfg_data_o = {30'h0, r_eth_err_irq_en, r_eth_rx_irq_en};
        `ETH_REG_RX_FCS:
            cfg_data_o = rx_fcs_i[31:0];
        `ETH_REG_TX_FCS:
            cfg_data_o = tx_fcs_i[31:0];
        default:
            cfg_data_o = 'h0;
        endcase
    end

    assign cfg_ready_o  = 1'b1;

endmodule
