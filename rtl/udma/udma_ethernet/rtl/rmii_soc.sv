/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

based on fpga.v
 
*/

// Language: Verilog 2001

/*
 * RMII top-level module
 */

module rmii_soc (
    // Internal 125 MHz clock
    input              clk_int,
    input              rst_int,
    input              clk_200_int,

    input wire [1:0]   phy_rxd,
    input wire         phy_crs_dv,
    output wire [1:0]  phy_txd,
    output wire        phy_tx_en,
    input wire         phy_rx_er,
       /*
        * AXI input
        */
    input wire         tx_axis_tvalid,
    input wire         tx_axis_tlast,
    input wire [7:0]   tx_axis_tdata,
    output wire        tx_axis_tready,
    input wire         tx_axis_tuser,
   
       /*
        * AXI output
        */
    output wire [7:0]  rx_axis_tdata,
    output wire        rx_axis_tvalid,
    output wire        rx_axis_tlast,
    output             rx_axis_tuser,

    /*
     * Status
     */

    output wire        tx_fifo_overflow,
    output wire        tx_fifo_bad_frame,
    output wire        tx_fifo_good_frame,
    output wire        rx_error_bad_frame,
    output wire        rx_error_bad_fcs,
    output wire        rx_fifo_overflow,
    output wire        rx_fifo_bad_frame,
    output wire        rx_fifo_good_frame

);

wire            mii_tx_clk;
wire            mii_rx_clk;
wire            mii_col;
wire            mii_crs;
wire            mii_rx_dv;
wire            mii_rx_er;
wire   [3:0]    mii_rxd;
wire            mii_tx_en;
wire   [3:0]    mii_txd;
wire            mii_tx_er;



IDELAYCTRL
idelayctrl_inst
(
    .REFCLK(clk_200_int),
    .RST(rst_int),
    .RDY()
);

//`ifndef ETH_LOOPBACK

//// IODELAY elements for RGMII interface to PHY
//wire [1:0] phy_rxd_delay;
//wire       phy_crs_dv_delay;

//IDELAYE2 #(
//    .IDELAY_TYPE("FIXED")
//)
//phy_rxd_idelay_0
//(
//    .IDATAIN(phy_rxd[0]),
//    .DATAOUT(phy_rxd_delay[0]),
//    .DATAIN(1'b0),
//    .C(1'b0),
//    .CE(1'b0),
//    .INC(1'b0),
//    .CINVCTRL(1'b0),
//    .CNTVALUEIN(5'd0),
//    .CNTVALUEOUT(),
//    .LD(1'b0),
//    .LDPIPEEN(1'b0),
//    .REGRST(1'b0)
//);

//IDELAYE2 #(
//    .IDELAY_TYPE("FIXED")
//)
//phy_rxd_idelay_1
//(
//    .IDATAIN(phy_rxd[1]),
//    .DATAOUT(phy_rxd_delay[1]),
//    .DATAIN(1'b0),
//    .C(1'b0),
//    .CE(1'b0),
//    .INC(1'b0),
//    .CINVCTRL(1'b0),
//    .CNTVALUEIN(5'd0),
//    .CNTVALUEOUT(),
//    .LD(1'b0),
//    .LDPIPEEN(1'b0),
//    .REGRST(1'b0)
//);

//IDELAYE2 #(
//    .IDELAY_VALUE(0),
//    .IDELAY_TYPE("FIXED")
//)
//phy_rx_en_idelay
//(
//    .IDATAIN(phy_crs_dv),
//    .DATAOUT(phy_crs_dv_delay),
//    .DATAIN(1'b0),
//    .C(1'b0),
//    .CE(1'b0),
//    .INC(1'b0),
//    .CINVCTRL(1'b0),
//    .CNTVALUEIN(5'd0),
//    .CNTVALUEOUT(),
//    .LD(1'b0),
//    .LDPIPEEN(1'b0),
//    .REGRST(1'b0)
//);
//`endif

mii_core
core_inst (
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    .clk(clk_int),
    .rst(rst_int),
    /*
     * Ethernet: 1000BASE-T RGMII
     */
    .phy_rx_clk(mii_rx_clk),
    .phy_rxd(mii_rxd),
    .phy_rx_dv(mii_rx_dv),
    .phy_rx_er(mii_rx_er),
    .phy_tx_clk(mii_tx_clk),
    .phy_txd(mii_txd),
    .phy_tx_en(mii_tx_en),
    .phy_tx_er(mii_tx_er),
    .tx_axis_tdata(tx_axis_tdata),
    .tx_axis_tvalid(tx_axis_tvalid),
    .tx_axis_tready(tx_axis_tready),
    .tx_axis_tlast(tx_axis_tlast),
    .tx_axis_tuser(tx_axis_tuser),
    .rx_axis_tdata(rx_axis_tdata),
    .rx_axis_tvalid(rx_axis_tvalid),
    .rx_axis_tlast(rx_axis_tlast),
    .rx_axis_tuser(rx_axis_tuser),
    .tx_fifo_overflow(tx_fifo_overflow),
    .tx_fifo_bad_frame(tx_fifo_bad_frame),
    .tx_fifo_good_frame(tx_fifo_good_frame),
    .rx_error_bad_frame(rx_error_bad_frame),
    .rx_error_bad_fcs(rx_error_bad_fcs),
    .rx_fifo_overflow(rx_fifo_overflow),
    .rx_fifo_bad_frame(rx_fifo_bad_frame),
    .rx_fifo_good_frame(rx_fifo_good_frame)
);

//`ifndef ETH_LOOPBACK

//util_mii_to_rmii #(
//  .INTF_CFG(0),
//  .RATE_10_100(1)
//) 
//mii_2_rmii_inst
//(

//  // MAC to MII(PHY)
//  .mac_tx_en(mii_tx_en),      //input             mac_tx_en,
//  .mac_txd(mii_txd),        //input    [3:0]    mac_txd,
//  .mac_tx_er(mii_tx_er),      //input             mac_tx_er,
//  //MII to MAC
//  .mii_tx_clk(mii_tx_clk),     //output            mii_tx_clk,
//  .mii_rx_clk(mii_rx_clk),     //output            mii_rx_clk,
//  .mii_col(mii_col),        //output            mii_col,
//  .mii_crs(mii_crs),        //output            mii_crs,
//  .mii_rx_dv(mii_rx_dv),      //output            mii_rx_dv,
//  .mii_rx_er(mii_rx_er),      //output            mii_rx_er,
//  .mii_rxd(mii_rxd),        //output   [3:0]    mii_rxd,
//  // RMII to PHY
//  .rmii_txd(phy_txd),       //output   [1:0]    rmii_txd,
//  .rmii_tx_en(phy_tx_en),     //output            rmii_tx_en,
//  // PHY to RMII
//  .phy_rxd(phy_rxd_delay),        //input    [1:0]    phy_rxd,
//  .phy_crs_dv(phy_crs_dv_delay),     //input             phy_crs_dv,
//  .phy_rx_er(phy_rx_er),      //input             phy_rx_er,
//  // External
//  .ref_clk(clk_int),        //input             ref_clk,
//  .reset_n(~rst_int)         //input             reset_n
//);

//`else

util_mii_to_rmii #(
  .INTF_CFG(0),
  .RATE_10_100(0)
) 
mii_2_rmii_inst
(

  // MAC to MII(PHY)
  .mac_tx_en(mii_tx_en),      //input             mac_tx_en,
  .mac_txd(mii_txd),        //input    [3:0]    mac_txd,
  .mac_tx_er(mii_tx_er),      //input             mac_tx_er,
  //MII to MAC
  .mii_tx_clk(mii_tx_clk),     //output            mii_tx_clk,
  .mii_rx_clk(mii_rx_clk),     //output            mii_rx_clk,
  .mii_col(mii_col),        //output            mii_col,
  .mii_crs(mii_crs),        //output            mii_crs,
  .mii_rx_dv(mii_rx_dv),      //output            mii_rx_dv,
  .mii_rx_er(mii_rx_er),      //output            mii_rx_er,
  .mii_rxd(mii_rxd),        //output   [3:0]    mii_rxd,
  // RMII to PHY
  .rmii_txd(phy_txd),       //output   [1:0]    rmii_txd,
  .rmii_tx_en(phy_tx_en),     //output            rmii_tx_en,
  // PHY to RMII
  .phy_rxd(phy_rxd),        //input    [1:0]    phy_rxd,
  .phy_crs_dv(phy_crs_dv),     //input             phy_crs_dv,
  .phy_rx_er(phy_rx_er),      //input             phy_rx_er,
  // External
  .ref_clk(clk_int),        //input             ref_clk,
  .reset_n(~rst_int)         //input             reset_n
);

//`endif

endmodule
