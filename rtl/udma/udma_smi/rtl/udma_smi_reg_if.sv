///////////////////////////////////////////////////////////////////////////////
//
// Description: SMI configuration interface
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Mustafa Karadayi (mustafa.karadayi@planv.tech)
//
///////////////////////////////////////////////////////////////////////////////

/* verilator lint_off REDEFMACRO */
`define SMI_REG_PHY_RW              5'b00000 //BASEADDR+0x00
`define SMI_REG_PHY_EN              5'b00001 //BASEADDR+0x04
`define SMI_REG_PHY_ND              5'b00010 //BASEADDR+0x08
`define SMI_REG_PHY_BUSY            5'b00011 //BASEADDR+0x0C
`define SMI_REG_PHY_ADDR            5'b00100 //BASEADDR+0x10
`define SMI_REG_REGISTER_ADDR       5'b00101 //BASEADDR+0x14
`define SMI_REG_TX_DATA             5'b00110 //BASEADDR+0x18
`define SMI_REG_RX_DATA             5'b00111 //BASEADDR+0x1C
/* verilator lint_on REDEFMACRO */

module udma_smi_reg_if
(
	input  logic 	                    clk_i,
	input  logic   	                    rstn_i,

	input  logic               [31:0]   cfg_data_i,
	input  logic                [4:0]   cfg_addr_i,
	input  logic                        cfg_valid_i,
	input  logic                        cfg_rwn_i,
	output logic               [31:0]   cfg_data_o,
	output logic                        cfg_ready_o,

    output logic	            		start_o,
    input  logic	            		busy_i,
    input  logic	            		nd_i,
    output logic	            		rw_o, // 0 for read, 1 for write
    output logic	            [4:0]	phy_addr_o,	
    output logic	            [4:0]	reg_addr_o,
    output logic	            [15:0]	wr_data_o,
    input  logic	            [15:0]	rd_data_i
);

    logic                [4:0] s_wr_addr;
    logic                [4:0] s_rd_addr;

    assign s_wr_addr = (cfg_valid_i & ~cfg_rwn_i) ? cfg_addr_i : 5'h0;
    assign s_rd_addr = (cfg_valid_i &  cfg_rwn_i) ? cfg_addr_i : 5'h0;

    logic               nd_reg = 1'b0;
    logic               s_nd_clr = 1'b0;

    always_ff @(posedge clk_i, negedge rstn_i)
    begin
        if(~rstn_i)
        begin
            start_o <= 'h0;
            rw_o <= 'h0; // 0 for read, 1 for write
            phy_addr_o <= 'h0;	
            reg_addr_o <= 'h0;
            wr_data_o <= 'h0;
        end
        else
        begin
            if(nd_i)
            begin
                nd_reg <= 1'b1;
            end
            else if(s_nd_clr)
            begin
                nd_reg <= 1'b0;
            end

            if (cfg_valid_i & ~cfg_rwn_i)
            begin
                case (s_wr_addr)
                `SMI_REG_PHY_RW:
                    rw_o    <= cfg_data_i[0];
                `SMI_REG_PHY_EN:
                    start_o         <= cfg_data_i[0];
                `SMI_REG_PHY_ADDR:
                    phy_addr_o    <= cfg_data_i[4:0];
                `SMI_REG_REGISTER_ADDR:
                    reg_addr_o         <= cfg_data_i[4:0];
                `SMI_REG_TX_DATA:
                    wr_data_o      <= cfg_data_i[15:0];
                endcase
            end
        end
    end //always

    always_comb
    begin
        cfg_data_o = 32'h0;

        s_nd_clr = 1'b0;
        if (cfg_valid_i & cfg_rwn_i)
        begin
            case (s_rd_addr)
            `SMI_REG_PHY_ND:
            begin
                cfg_data_o[0] = {31'h0, nd_reg};
                s_nd_clr = 1'b1;
            end
            `SMI_REG_PHY_BUSY:
                cfg_data_o[0] = {31'h0, busy_i};
            `SMI_REG_RX_DATA:
                cfg_data_o = {16'h0, rd_data_i};
            default:
                cfg_data_o = 'h0;
            endcase
        end
    end

    assign cfg_ready_o  = 1'b1;

endmodule
