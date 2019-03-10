



module fsmc_mux_async_slave
	#(
		parameter 
			ADDR_WIDTH = 19, 
			DATA_WIDTH = 16
	)
	(
		input logic 											clk_i,
		inout logic[DATA_WIDTH - 1 : 0] 					dat_io,
		input logic[ADDR_WIDTH - DATA_WIDTH - 1 : 0] adr_hi,
		input logic 											we_i, 
																	oe_i, 
																	ce_i, 
																	al_i,
																	
		input logic 											ack_i, 
																	
		output logic 											we_o,
																	stb_o,
		
		output logic[ADDR_WIDTH - 1 : 0] 				adr_o,
		input logic[DATA_WIDTH - 1 : 0] 					dat_i,
		output logic[DATA_WIDTH - 1 : 0] 				dat_o
	);
	
	logic[1 : 0] we_sh, oe_sh;
	
	always_ff @ (posedge clk_i) begin
		we_sh = {we_sh[0], we_i};
		oe_sh = {oe_sh[0], oe_i};
	end
	
	wire we_rise = ~we_sh[1] & we_sh[0];
	wire oe_fall = ~oe_sh[0] & oe_sh[1];
	wire woe	= we_rise | oe_fall;
	
	always_latch begin
		if (ack_i)
			stb_o = '0;
		else if (woe & ~ce_i)
			stb_o = '1;
	end
	
	always_latch begin
		if (~ce_i & oe_fall)
			we_o = '0;
		else if ((~ce_i & we_rise) | ack_i)
			we_o = '1;
	end
		
	always_latch begin
		if (~ce_i & ~al_i) begin
			adr_o[DATA_WIDTH - 1 : 0] = dat_io[DATA_WIDTH - 1 : 0];
		end
	end
	
	always_latch
		if (~ce_i) adr_o[ADDR_WIDTH - 1 : DATA_WIDTH] = adr_hi[ADDR_WIDTH - DATA_WIDTH - 1 : 0];

	
	assign dat_io[DATA_WIDTH - 1 : 0] = ~oe_i ? dat_i[DATA_WIDTH - 1 : 0] : 'z;
	
		
	always_latch
		if (~we_i) dat_o[DATA_WIDTH - 1 : 0] = dat_io[DATA_WIDTH - 1 : 0];
	
endmodule


