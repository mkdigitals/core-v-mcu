///////////////////////////////////////////////////////////////////////////////
//
// Description: SMI control logic
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Mustafa Karadayi (mustafa.karadayi@planv.tech)
//
///////////////////////////////////////////////////////////////////////////////

module udma_smi_ctrl #(
    parameter	SLOW_CLK_COUNT = 64
) (
		input  logic            clk_i,
		input  logic            rstn_i,
		input  logic            mdi_i,
		output logic			mdo_o,
		output logic			md_oen_o,
		output logic 			mdc_o,
		input  logic			start_i,
		output logic			busy_o,
		output logic			nd_o,
		input  logic			rw_i, // 0 for read, 1 for write
		input  logic	[4:0]	phy_addr_i,	
		input  logic	[4:0]	reg_addr_i,
		input  logic	[15:0]	wr_data_i,
		output logic	[15:0]	rd_data_o		
		);

	localparam CLK_HIGH_TIME_IN_CLK_CYCLES = SLOW_CLK_COUNT/2;
	localparam CLK_HIGH_TIME_IN_CLK_CYCLES_M1 = CLK_HIGH_TIME_IN_CLK_CYCLES - 1;

	logic [15:0]	clk_count	= 16'h0;

	logic clk_en				= 1'b0;

	always_ff @(posedge clk_i or negedge rstn_i)
	begin
		if(!rstn_i)
		begin
			clk_count <= 16'h0;
			clk_en <= 1'b0;
			mdc_o <= 1'b0;
		end
		else
		begin
			if(clk_count == CLK_HIGH_TIME_IN_CLK_CYCLES_M1)
			begin
				clk_en <= mdc_o == 1'b0 ? 1'b1 : 1'b0;
				clk_count <= 'h0;
				mdc_o <= ~mdc_o;
			end
			else
			begin
				clk_en <= 1'b0;
				clk_count <= clk_count + 16'h1;
			end
		end
	end

	localparam	ST_IDLE				= 3'h0,
				ST_PREAMBLE			= 3'h1,
				ST_SOF_OPCODE_ADDR	= 3'h2,
				ST_TURN_AROUND		= 3'h3,
				ST_DATA				= 3'h4;

	logic	[2:0]	state			= ST_IDLE;
	logic	[1:0]	sof_pattern		= 2'b01;
	logic	[1:0]	op_code_wr		= 2'b01;
	logic	[1:0]	op_code_rd		= 2'b10;
	logic			nd_reg			= 1'b0;
	logic			nd_reg_d1		= 1'b0;
	logic			start_reg 		= 1'b0;	
	logic			rw_reg			= 1'b0;
	logic	[15:0]	wr_data_reg		= 16'h0;
	logic	[4:0]	data_count		= 5'h0;
	logic	[15:0]	serializer		= 16'h0;

	assign busy_o = state != ST_IDLE | start_i | ~rstn_i | start_reg;
	assign nd_o	= nd_reg & ~nd_reg_d1;
	always_ff @(posedge clk_i or negedge rstn_i) begin
		if(!rstn_i)
		begin
			state			<= ST_IDLE;
			sof_pattern		<= 2'b01;
			op_code_wr		<= 2'b01;
			op_code_rd		<= 2'b10;
			nd_reg			<= 1'b0;
			start_reg		<= 1'b0;	
			wr_data_reg		<= 16'h0;
			data_count		<= 5'h0;
			rw_reg			<= 1'b0;
			serializer		<= 16'h0;
		end
		else
		begin
			nd_reg_d1 <= nd_reg;

			start_reg <= (start_i & state == ST_IDLE) ? 1'b1 : start_reg;

			if(clk_en)
			begin
				case(state)
				ST_IDLE:
				begin
					data_count <= 5'h0;
					nd_reg <= 1'b0;
					if(start_reg)
					begin
						rw_reg 	  <= rw_i;
						start_reg <= 1'b0;
						state <= ST_PREAMBLE;
						wr_data_reg <=	wr_data_i;
						md_oen_o <= 1'b1;
						mdo_o <= 1'b1;
						if(rw_i)
						begin
							serializer <= {2'b00, sof_pattern[1:0], op_code_wr[1:0], phy_addr_i[4:0], reg_addr_i[4:0]};
						end
						else
						begin
							serializer <= {2'b00, sof_pattern[1:0], op_code_rd[1:0], phy_addr_i[4:0], reg_addr_i[4:0]};
						end
					end
					else
					begin
						md_oen_o <= 1'b0;
					end
				end
				ST_PREAMBLE:
				begin
					if(data_count == 5'h1F)
					begin
						data_count <= 5'h0;
						state <= ST_SOF_OPCODE_ADDR;
					end
					else
					begin
						data_count <= data_count + 5'h01;
					end
				end
				ST_SOF_OPCODE_ADDR:
				begin
					if(data_count == 5'h0D)
					begin
						data_count <= 5'h0;
						state <= ST_TURN_AROUND;
					end
					else
					begin
						data_count <= data_count + 5'h01;
						serializer <= {serializer[14:0], 1'b0};
					end
					mdo_o <= serializer[13];
				end
				ST_TURN_AROUND:
				begin
				    if(rw_reg)
                    begin
                        serializer[15:0] <= wr_data_reg[15:0];
                    end
                    else
                    begin
                        md_oen_o <= 1'b0;
                    end
					if(data_count == 5'h01)
					begin
						data_count <= 5'h0;
						state <= ST_DATA;
					end
					else
					begin
						data_count <= data_count + 5'h01;
					end
				end
				ST_DATA:
				begin
					if(rw_reg)
					begin
						if(data_count == 5'h0F)
						begin
							data_count <= 5'h0;
							state <= ST_IDLE;
						end
						else
						begin
							data_count <= data_count + 5'h01;
							
						end
						serializer <= {serializer[14:0], 1'b0};
						mdo_o <= serializer[15];
					end
					else
					begin
						if(data_count == 5'h10)
						begin
							data_count <= 5'h0;
							state <= ST_IDLE;
							rd_data_o <= {serializer[14:0],mdi_i};
							nd_reg <= 1'b1;
						end
						else
						begin
							data_count <= data_count + 5'h01;	
						end
						serializer <= {serializer[14:0],mdi_i}; 
					end
				end
				endcase
			end			
		end
	end

endmodule
