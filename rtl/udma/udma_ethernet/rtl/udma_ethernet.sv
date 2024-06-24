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
// Description: ETHERNET top level
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Antonio Pullini (pullinia@iis.ee.ethz.ch)
//
// Edited By    : Mustafa Karadayi(PlanV    -   mustafa.karadayi@planv.tech)
//
///////////////////////////////////////////////////////////////////////////////

module udma_ethernet #(
    parameter L2_AWIDTH_NOAL = 12,
    parameter TRANS_SIZE     = 16,
    parameter ETHID_WIDTH    = 2
) (
    input  logic                      sys_clk_i,
    input  logic                      periph_clk_i, //probably no usage, we will need another clock
    //input  logic                      periph_clk_i_90, //probably no usage, we will need another clock
    input  logic                      periph_rstn_i, //probably no usage, we will need another clock
    input  logic                      ref_clk_i_200, // 200MHz delay gen ref clock
	input  logic   	                  rstn_i,

    /*
     * Ethernet: 1000BASE-T RGMII
     */
    // input wire         phy_rx_clk,
    // input wire [3:0]   phy_rxd,
    // input wire         phy_rx_ctl,
    // output wire        phy_tx_clk,
    // output wire [3:0]  phy_txd,
    // output wire        phy_tx_ctl,
    // output wire        phy_reset_n,
    // input wire         phy_int_n,
    // input wire         phy_pme_n,

    input wire [1:0]    phy_rxd,
    input wire          phy_crs_dv,
    output wire [1:0]   phy_txd,
    output wire         phy_tx_en,
    input wire          phy_rx_er,

    /*
    *   Interrupts
    */
    output wire        eth_rx_event_o,

 input  logic               [31:0] cfg_data_i,
 input  logic                [4:0] cfg_addr_i,
 input  logic                      cfg_valid_i,
 input  logic                      cfg_rwn_i,
 output logic                      cfg_ready_o,
 output logic               [31:0] cfg_data_o,

output logic [L2_AWIDTH_NOAL-1:0] cfg_rx_startaddr_o,       
output logic     [TRANS_SIZE-1:0] cfg_rx_size_o,            
output logic                [1:0] cfg_rx_datasize_o,        
output logic                      cfg_rx_continuous_o,      
output logic                      cfg_rx_en_o,              
output logic                      cfg_rx_clr_o,             
input  logic                      cfg_rx_en_i,              
input  logic                      cfg_rx_pending_i,         
input  logic [L2_AWIDTH_NOAL-1:0] cfg_rx_curr_addr_i,       
input  logic     [TRANS_SIZE-1:0] cfg_rx_bytes_left_i,      

output logic [L2_AWIDTH_NOAL-1:0] cfg_tx_startaddr_o,       
output logic     [TRANS_SIZE-1:0] cfg_tx_size_o,            
output logic                [1:0] cfg_tx_datasize_o,        
output logic                      cfg_tx_continuous_o,      
output logic                      cfg_tx_en_o,              
output logic                      cfg_tx_clr_o,             
input  logic                      cfg_tx_en_i,              
input  logic                      cfg_tx_pending_i,         
input  logic [L2_AWIDTH_NOAL-1:0] cfg_tx_curr_addr_i,       
input  logic     [TRANS_SIZE-1:0] cfg_tx_bytes_left_i,      

output logic                      data_tx_req_o,
input  logic                      data_tx_gnt_i,
output logic                [1:0] data_tx_datasize_o,
input  logic               [31:0] data_tx_i,
input  logic                      data_tx_valid_i,
output logic                      data_tx_ready_o,

output logic                [1:0] data_rx_datasize_o,
output logic               [31:0] data_rx_o,
output logic                      data_rx_valid_o,
input  logic                      data_rx_ready_i
);

    logic               [7:0]  s_eth_status;
    logic                      s_eth_rx_irq_en;
    logic                      s_eth_err_irq_en;
    logic                      s_eth_en_rx;
    logic                      s_eth_en_tx;
    /*
    *  TX Buffer AXIS Input   
    */
    wire    [31:0]   tx_buffer_axis_tdata;
    wire             tx_buffer_axis_tvalid;
    wire    [1:0]    tx_buffer_axis_tsize;
    wire             tx_buffer_axis_tready;
    wire             tx_buffer_axis_tlast;
    wire             tx_buffer_axis_tuser;
    /*
     * Core AXIS input
     */
    wire    [7:0]   eth_tx_axis_tdata;
    wire            eth_tx_axis_tvalid;
    wire            eth_tx_axis_tready;
    wire            eth_tx_axis_tlast;
    wire            eth_tx_axis_tuser;

    /*
     * AXIS output
     */
    wire    [7:0]  eth_rx_axis_tdata;
    wire           eth_rx_axis_tvalid;
    wire           eth_rx_axis_tready;
    wire           eth_rx_axis_tlast;
    wire           eth_rx_axis_tuser;

    /*
     * Status
     */
    wire            eth_tx_fifo_overflow; //tied
    wire            eth_tx_fifo_bad_frame; //tied
    wire            eth_tx_fifo_good_frame; //tied
    wire            eth_rx_error_bad_frame; //tied
    wire            eth_rx_error_bad_fcs; //tied
    wire            eth_rx_fifo_overflow; //tied
    wire            eth_rx_fifo_bad_frame; //tied
    wire            eth_rx_fifo_good_frame; //tied
    wire    [1:0]   eth_speed; //tied
    wire    [31:0]  eth_rx_fcs_reg; //tied
    wire    [31:0]  eth_tx_fcs_reg; //tied
    wire    [7:0]   eth_status = {eth_tx_fifo_overflow,
                                eth_tx_fifo_bad_frame,
                                eth_tx_fifo_good_frame,
                                eth_rx_error_bad_frame,
                                eth_rx_error_bad_fcs,
                                eth_rx_fifo_overflow,
                                eth_rx_fifo_bad_frame,
                                eth_rx_fifo_good_frame};

    logic    [L2_AWIDTH_NOAL-1:0]  reg_tx_startaddr_s;
    logic        [TRANS_SIZE-1:0]  reg_tx_size_s;
    logic                          reg_tx_continuous_s;
    logic                          reg_tx_en_to_ctrl;
    logic                          reg_tx_clr_s;
    logic                          reg_tx_en_from_ctrl;
    logic                          reg_tx_pending_s;
    logic    [L2_AWIDTH_NOAL-1:0]  reg_tx_curr_addr_s;
    logic        [TRANS_SIZE-1:0]  reg_tx_bytes_left_s;
    logic                          s_tx_busy;

    logic    [L2_AWIDTH_NOAL-1:0]  reg_rx_startaddr0_s;
    logic    [L2_AWIDTH_NOAL-1:0]  reg_rx_startaddr1_s;
    logic    [L2_AWIDTH_NOAL-1:0]  reg_rx_startaddr2_s;
    logic    [L2_AWIDTH_NOAL-1:0]  reg_rx_startaddr3_s;
    (* KEEP = "TRUE" *)logic       [TRANS_SIZE-1:0]  reg_rx_size_s;
    logic                   [1:0]  reg_rx_pointer_s;
    logic                          reg_rx_continuous_s;
    logic                          reg_rx_en_to_ctrl;
    logic                          reg_rx_en_from_ctrl;
    logic                          reg_rx_clr_s;
    logic                          reg_rx_pending_s;
    logic    [L2_AWIDTH_NOAL-1:0]  reg_rx_curr_addr_s;
    logic        [TRANS_SIZE-1:0]  reg_rx_bytes_left_s;

    logic                          rx_channel_enable;
    logic                          rx_buffer_valid;
    logic                          rx_buffer_ready;

    logic                          rx_queue_ready;
    logic                   [7:0]  rx_buffer_axis_tdata;
    logic                          rx_buffer_axis_tvalid;
    logic                          rx_buffer_axis_tready;
    logic                          rx_buffer_axis_tlast;
    logic                          rx_buffer_axis_tuser;

    assign rx_buffer_ready = rx_channel_enable ? data_rx_ready_i : 1'b0;
    assign data_rx_valid_o = rx_channel_enable ? rx_buffer_valid : 1'b0;

    assign rx_buffer_axis_tdata = eth_rx_axis_tdata;
    assign rx_buffer_axis_tvalid = s_eth_en_rx & rx_queue_ready ? eth_rx_axis_tvalid : 1'b0;
    assign rx_buffer_axis_tlast = s_eth_en_rx ? eth_rx_axis_tlast : 1'b0;
    assign rx_buffer_axis_tuser = s_eth_en_rx ? eth_rx_axis_tuser : 1'b0;
    assign eth_rx_axis_tready   = rx_queue_ready ? rx_buffer_axis_tready : 1'b0;

    //CONFIGURATION
    wire        mac_gmii_tx_en = s_eth_en_tx;

    udma_ethernet_reg_if #(
        .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
        .TRANS_SIZE(TRANS_SIZE)
    ) u_reg_if (
        .clk_i              ( sys_clk_i           ),
        .rstn_i             ( rstn_i              ),

        .cfg_data_i         ( cfg_data_i          ),
        .cfg_addr_i         ( cfg_addr_i          ),
        .cfg_valid_i        ( cfg_valid_i         ),
        .cfg_rwn_i          ( cfg_rwn_i           ),
        .cfg_ready_o        ( cfg_ready_o         ),
        .cfg_data_o         ( cfg_data_o          ),

        .cfg_rx_startaddr0_o( reg_rx_startaddr0_s ),
        .cfg_rx_startaddr1_o( reg_rx_startaddr1_s ),
        .cfg_rx_startaddr2_o( reg_rx_startaddr2_s ),
        .cfg_rx_startaddr3_o( reg_rx_startaddr3_s ),
        .cfg_rx_pointer_i   ( reg_rx_pointer_s    ),
        .cfg_rx_size_i      ( reg_rx_size_s       ),
        .cfg_rx_continuous_o( reg_rx_continuous_s ),
        .cfg_rx_en_o        ( reg_rx_en_to_ctrl   ),
        .cfg_rx_clr_o       ( reg_rx_clr_s        ),
        .cfg_rx_en_i        ( reg_rx_en_from_ctrl ),
        .cfg_rx_pending_i   ( reg_rx_pending_s    ),
        .cfg_rx_curr_addr_i ( reg_rx_curr_addr_s  ),
        .cfg_rx_bytes_left_i( reg_rx_bytes_left_s ),

        .cfg_tx_startaddr_o ( reg_tx_startaddr_s  ),
        .cfg_tx_size_o      ( reg_tx_size_s       ),
        .cfg_tx_continuous_o( reg_tx_continuous_s ),
        .cfg_tx_en_o        ( reg_tx_en_to_ctrl   ),
        .cfg_tx_clr_o       ( reg_tx_clr_s        ),
        .cfg_tx_en_i        ( reg_tx_en_from_ctrl ),
        .cfg_tx_pending_i   ( reg_tx_pending_s    ),
        .cfg_tx_curr_addr_i ( reg_tx_curr_addr_s  ),
        .cfg_tx_bytes_left_i( reg_tx_bytes_left_s ),

        .status_i           ( eth_status        ),
        .speed_i            ( eth_speed         ),
        .rx_fcs_i           ( eth_rx_fcs_reg    ),
        .tx_fcs_i           ( eth_tx_fcs_reg    ),
        .rx_irq_en_o        ( s_eth_rx_irq_en   ),
        .err_irq_en_o       ( s_eth_err_irq_en  ),
        .en_rx_o			( s_eth_en_rx       ),
        .en_tx_o			( s_eth_en_tx       ),
        .tx_busy_i          ( s_tx_busy         )
    );

    //////////////////////////////////////////////////////////
    // TX CONTROLLER
    //////////////////////////////////////////////////////////
    udma_eth_tx_controller #(
    .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
    .TRANS_SIZE(TRANS_SIZE)
    )
    u_eth_tx_ctrl
    (
    .clk_i(sys_clk_i),
    .rstn_i(rstn_i),
    ////////////// interface to core //////////////////////////
    .cfg_tx_startaddr_o(cfg_tx_startaddr_o),
    .cfg_tx_size_o(cfg_tx_size_o),
    .cfg_tx_datasize_o(cfg_tx_datasize_o),
    .cfg_tx_continuous_o(cfg_tx_continuous_o),
    .cfg_tx_en_o(cfg_tx_en_o),
    .cfg_tx_clr_o(cfg_tx_clr_o),
    .cfg_tx_en_i(cfg_tx_en_i),
    .cfg_tx_pending_i(cfg_tx_pending_i),
    .cfg_tx_curr_addr_i(cfg_tx_curr_addr_i),
    .cfg_tx_bytes_left_i(cfg_tx_bytes_left_i),

    ////////////// interface with the register control ////////

    .reg_tx_startaddr_i(reg_tx_startaddr_s),
    .reg_tx_size_i(reg_tx_size_s),
    .reg_tx_continuous_i(reg_tx_continuous_s),
    .reg_tx_en_i(reg_tx_en_to_ctrl),
    .reg_tx_clr_i(reg_tx_clr_s),
    .reg_tx_en_o(reg_tx_en_from_ctrl),
    .reg_tx_pending_o(reg_tx_pending_s),
    .reg_tx_curr_addr_o(reg_tx_curr_addr_s),
    .reg_tx_bytes_left_o(reg_tx_bytes_left_s),
    .busy_o(s_tx_busy),

    ///////////// udma data channel /////////////////////
    
    .data_tx_req_o(data_tx_req_o),
    .data_tx_gnt_i(data_tx_gnt_i),
    .data_tx_datasize_o(data_tx_datasize_o),
    .data_tx_i(data_tx_i),
    .data_tx_valid_i(data_tx_valid_i),
    .data_tx_ready_o(data_tx_ready_o),

    ////////////// eth axis channel ///////////////////////

    .m_axis_tdata_o(tx_buffer_axis_tdata),
    .m_axis_tsize_o(tx_buffer_axis_tsize),
    .m_axis_tvalid_o(tx_buffer_axis_tvalid),
    .m_axis_tuser_o(tx_buffer_axis_tuser),
    .m_axis_tlast_o(tx_buffer_axis_tlast),
    .m_axis_tready_i(tx_buffer_axis_tready) 
    );


    //////////////////////////////////////////////////////////
    // RX CONTROLLER
    //////////////////////////////////////////////////////////
    udma_eth_rx_controller #(
    .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
    .TRANS_SIZE(TRANS_SIZE)
    )
    u_eth_rx_ctrl
    (
    //////////////// system clk and its associated reset
    .sys_clk_i(sys_clk_i),
    .sys_rstn_i(rstn_i),
    //////////////// 125MHz clk and its associated reset
    .eth_clk_i(periph_clk_i),
    .eth_rstn_i(periph_rstn_i),
    ////////////// interface to core //////////////////////////
    .cfg_rx_startaddr_o(cfg_rx_startaddr_o),
    .cfg_rx_size_o(cfg_rx_size_o),
    .cfg_rx_datasize_o(cfg_rx_datasize_o),
    .cfg_rx_continuous_o(cfg_rx_continuous_o),
    .cfg_rx_en_o(cfg_rx_en_o),
    .cfg_rx_clr_o(cfg_rx_clr_o),
    .cfg_rx_en_i(cfg_rx_en_i),
    .cfg_rx_pending_i(cfg_rx_pending_i),
    .cfg_rx_curr_addr_i(cfg_rx_curr_addr_i),
    .cfg_rx_bytes_left_i(cfg_rx_bytes_left_i),

    ////////////// interface with the register control ////////

    .reg_rx_startaddr0_i(reg_rx_startaddr0_s),
    .reg_rx_startaddr1_i(reg_rx_startaddr1_s),
    .reg_rx_startaddr2_i(reg_rx_startaddr2_s),
    .reg_rx_startaddr3_i(reg_rx_startaddr3_s),
    .reg_rx_pointer_o(reg_rx_pointer_s),
    .reg_rx_size_o(reg_rx_size_s),
    .reg_rx_continuous_i(reg_rx_continuous_s),
    .reg_rx_clr_i(reg_rx_clr_s),
    .reg_rx_en_o(reg_rx_en_from_ctrl),
    .reg_rx_pending_o(reg_rx_pending_s),
    .reg_rx_curr_addr_o(reg_rx_curr_addr_s),
    .reg_rx_bytes_left_o(reg_rx_bytes_left_s),

    ///////////// udma data channel control  /////////////////////
    
    .rx_buffer_ready_i(rx_buffer_ready),
    .rx_buffer_rd_en_o(rx_channel_enable),
    .rx_buffer_valid_i(rx_buffer_valid),
    ////////////// eth axis channel monitor///////////////////////

    .s_axis_tvalid_i(rx_buffer_axis_tvalid),
    .s_axis_tlast_i(rx_buffer_axis_tlast),
    .s_axis_tready_i(rx_buffer_axis_tready),

    //////////////  rx_interrupt        //////////////////////////////
    .eth_rx_event(eth_rx_event_o),
    .eth_error_event(),
    //////////////  packet_queue_ready    //////////////////////////////
    .packet_queue_ready_o(rx_queue_ready)
    );


    eth_axis_rx_buffer rx_buffer_i
    (
    .s_clk_i(periph_clk_i),             //  input   logic   
    .s_rstn_i(periph_rstn_i),           //  input   logic   
    .s_axis_tdata(rx_buffer_axis_tdata),   //  input   logic   [7:0]
    .s_axis_tvalid(rx_buffer_axis_tvalid), //  input   logic   
    .s_axis_tuser(rx_buffer_axis_tuser),   //  input   logic   
    .s_axis_tlast(rx_buffer_axis_tlast),   //  input   logic   
    .s_axis_tready(rx_buffer_axis_tready), //  output  logic   

    .m_clk_i(sys_clk_i),                        //  input   logic           
    .m_rstn_i(rstn_i),                          //  input   logic           
    .m_axis_tdata(data_rx_o),          //  output  logic   [31:0]  
    .m_axis_byte_count(data_rx_datasize_o), //  input   logic   [1:0]   
    .m_axis_tvalid(rx_buffer_valid),        //  output  logic           
    .m_axis_tuser(),           //  output  logic           
    .m_axis_tlast(),           //  output  logic           
    .m_axis_tready(rx_buffer_ready)         //  input   logic           
    );

    eth_axis_tx_buffer tx_buffer_i
    (
    .s_clk_i(sys_clk_i),                    //  input   logic          
    .s_rstn_i(rstn_i),                      //  input   logic          
    .s_axis_tdata(tx_buffer_axis_tdata),      //  input   logic   [31:0] 
    .s_axis_byte_count(tx_buffer_axis_tsize),              //  input   logic   
    .s_axis_tvalid(tx_buffer_axis_tvalid),    //  input   logic          
    .s_axis_tuser(tx_buffer_axis_tuser),       //  input   logic          
    .s_axis_tlast(tx_buffer_axis_tlast),       //  input   logic          
    .s_axis_tready(tx_buffer_axis_tready),     //  output  logic           

    .m_clk_i(periph_clk_i),                 //  input   logic          
    .m_rstn_i(periph_rstn_i),               //  input   logic          
    .m_axis_tdata(eth_tx_axis_tdata),       //  output  logic   [7:0]   
    .m_axis_tvalid(eth_tx_axis_tvalid),     //  output  logic           
    .m_axis_tuser(eth_tx_axis_tuser),       //  output  logic           
    .m_axis_tlast(eth_tx_axis_tlast),       //  output  logic           
    .m_axis_tready(eth_tx_axis_tready)      //  input   logic          
    );
 /*
    rgmii_soc rgmii_soc1
    (
        .rst_int(~periph_rstn_i),
        .clk_int(periph_clk_i), //125 MHz clock
        .clk90_int(periph_clk_i_90), //125 MHz Clock with 90 degree phase shift
        .clk_200_int(ref_clk_i_200), // 200 MHz clock for inout delays ref_clk
        .phy_rx_clk(phy_rx_clk),
        .phy_rxd(phy_rxd),
        .phy_rx_ctl(phy_rx_ctl),
        .phy_tx_clk(phy_tx_clk),
        .phy_txd(phy_txd),
        .phy_tx_ctl(phy_tx_ctl),
        .phy_reset_n(phy_reset_n),
        .phy_int_n(phy_int_n),
        .phy_pme_n(phy_pme_n),
        .mac_gmii_tx_en(),
        .tx_axis_tdata(eth_tx_axis_tdata),
        .tx_axis_tvalid(eth_tx_axis_tvalid),
        .tx_axis_tready(eth_tx_axis_tready),
        .tx_axis_tlast(eth_tx_axis_tlast),
        .tx_axis_tuser(eth_tx_axis_tuser),
        .rx_axis_tdata(eth_rx_axis_tdata),
        .rx_axis_tvalid(eth_rx_axis_tvalid),
        .rx_axis_tlast(eth_rx_axis_tlast),
        .rx_axis_tuser(eth_rx_axis_tuser),
        .tx_fifo_overflow(eth_tx_fifo_overflow),
        .tx_fifo_bad_frame(eth_tx_fifo_bad_frame),
        .tx_fifo_good_frame(eth_tx_fifo_good_frame),
        .rx_error_bad_frame(eth_rx_error_bad_frame),
        .rx_error_bad_fcs(eth_rx_error_bad_fcs),
        .rx_fcs_reg(eth_rx_fcs_reg),
        .tx_fcs_reg(eth_tx_fcs_reg),
        .rx_fifo_overflow(eth_rx_fifo_overflow),
        .rx_fifo_bad_frame(eth_rx_fifo_bad_frame),
        .rx_fifo_good_frame(eth_rx_fifo_good_frame),
        .speed(eth_speed)
    );
*/

    rmii_soc rmii_soc1
    (
        .rst_int(~periph_rstn_i),
        .clk_int(periph_clk_i), //125 MHz clock
        .clk_200_int(ref_clk_i_200), // 200 MHz clock for inout delays ref_clk
        .phy_rxd(phy_rxd),
        .phy_crs_dv(phy_crs_dv),
        .phy_txd(phy_txd),
        .phy_tx_en(phy_tx_en),
        .phy_rx_er(phy_rx_er),
        .tx_axis_tdata(eth_tx_axis_tdata),
        .tx_axis_tvalid(eth_tx_axis_tvalid),
        .tx_axis_tready(eth_tx_axis_tready),
        .tx_axis_tlast(eth_tx_axis_tlast),
        .tx_axis_tuser(eth_tx_axis_tuser),
        .rx_axis_tdata(eth_rx_axis_tdata),
        .rx_axis_tvalid(eth_rx_axis_tvalid),
        .rx_axis_tlast(eth_rx_axis_tlast),
        .rx_axis_tuser(eth_rx_axis_tuser),
        .tx_fifo_overflow(eth_tx_fifo_overflow),
        .tx_fifo_bad_frame(eth_tx_fifo_bad_frame),
        .tx_fifo_good_frame(eth_tx_fifo_good_frame),
        .rx_error_bad_frame(eth_rx_error_bad_frame),
        .rx_error_bad_fcs(eth_rx_error_bad_fcs),
        .rx_fifo_overflow(eth_rx_fifo_overflow),
        .rx_fifo_bad_frame(eth_rx_fifo_bad_frame),
        .rx_fifo_good_frame(eth_rx_fifo_good_frame)
    );

endmodule // udma_ethernet_top
