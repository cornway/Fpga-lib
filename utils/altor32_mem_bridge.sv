
`define ALTOR_32L_TO_16_BRIDGE

/*

*/

`ifdef ALTOR_32L_TO_16_BRIDGE

module altor_mem_bridge
#(
	parameter
		ADRW		= 18
)
	(
		input logic				clk_i, /*sys con*/
		input logic				rst_i, /**/
		
		/*wishbone cpu slave*/
		
		
		input logic				alt_we_i,
									alt_stb_i,
									alt_cyc_i,
		
		input logic[3 : 0]	alt_sel_i,
		
		input logic[2 : 0]	alt_cti_i, /*unused in altor32 lite*/
		
		output logic			alt_stall_o,
									alt_ack_o,
									
		input logic[31 : 0]	alt_dat_i,
									alt_adr_i,
									
		output logic[31 : 0]	alt_dat_o,
		
		/*wishbone cpu slave*/
		
		
		/*wishbone mem master*/
		
		output logic			mem_we_o,
									mem_stb_o,
		
									
		output logic[1 : 0]	mem_sel_o,
		
		input logic				mem_ack_i,
									mem_cyc_i,
		
		input logic[15 : 0]	mem_dat_i,
		
		output logic[15 : 0] mem_dat_o,
		output logic[ADRW - 1 : 0] mem_adr_o
		
		/*wishbone mem master*/
	);
	
	
						
	wire 	rw_none,
			rw16l,
			rw16h,
			byte0, 
			byte1,
			byte2,
			byte3;
	
	wire[ADRW - 1 : 0] mem_adr;
	wire[15 : 0] 	alt_dat_il,
						alt_dat_ih;
						
	reg[15 : 0] 	alt_dat_ol,
						alt_dat_oh;
						
	assign alt_dat_o = {alt_dat_oh, alt_dat_ol};
	
	assign 	mem_adr = alt_adr_i[ADRW - 1 : 0],
				alt_dat_il = alt_dat_i[15 : 0],
				alt_dat_ih = alt_dat_i[31 : 16];
	
	assign
		byte0 = ~alt_sel_i[0],
		byte1 = ~alt_sel_i[1],
		byte2 = ~alt_sel_i[2],
		byte3 = ~alt_sel_i[3],
		rw16l = byte0 | byte1,
		rw16h = byte2 | byte3;
		
		
	localparam [0 : 0]
		RW16L		= 0,
		RW16H		= 1;
		
	localparam	[1 : 0]
			IDLE			= 0,
			WAIT_ACK		= 1,
			WAIT			= 2,
			PAUSE			= 3;
		
	logic[1 : 0] 	state = IDLE,
						next_state = IDLE;
		
	logic 	rw_seq = RW16L, 
				rw_seq_next = RW16L;
	
	always_comb begin
		if (alt_stb_i & mem_cyc_i)
			alt_stall_o = '1;
		else 
			alt_stall_o = '0;
	end
	
	always_comb begin
		state = next_state;
		rw_seq = rw_seq_next;
	end
	
	always_ff @ (posedge clk_i) begin
		if (rst_i) begin
			alt_ack_o <= '0;
			mem_sel_o <= '1;
			mem_stb_o <= '0;
			mem_we_o <= '1;
			mem_adr_o <= '0;
			mem_dat_o <= '0;
			rw_seq_next <= RW16L;
			next_state <= IDLE;
		end 
		else
		begin
		
		case (state)
			IDLE : begin
						alt_ack_o <= '0;
						mem_sel_o <= '1;
						
						if (alt_stb_i & ~mem_cyc_i) begin
								mem_stb_o <= '1;
								mem_we_o <= alt_we_i;
								
								mem_sel_o 		<= 	rw16l ? {byte1, byte0} : {byte3, byte2};
								mem_adr_o 		<= 	rw16l ? mem_adr : mem_adr + 1'b1;
								rw_seq_next 	<= 	rw16l ? RW16L : RW16H;
								
								if (mem_we_o)
									mem_dat_o 	<= 	rw16l ? alt_dat_il : alt_dat_ih;
								
								next_state <= WAIT_ACK;
						end else begin
							mem_stb_o <= '0;
							mem_adr_o <= '0;
							mem_dat_o <= '0;
							mem_we_o <= '1;
						end
					end
			WAIT_ACK : begin
						if (mem_ack_i) begin
							case (rw_seq)
								RW16L : begin
											if (~mem_we_o)
												alt_dat_ol <= mem_dat_i;
												
											if (rw16h) begin
												rw_seq_next <= RW16H;
												mem_sel_o <= {byte3, byte2};
												mem_adr_o <= mem_adr + 1'b1;
												
												if (mem_we_o)
													mem_dat_o <= alt_dat_ih;
											end else begin
												mem_stb_o <= '0;
												next_state <= WAIT;
											end
										end
								RW16H : begin
											if (~mem_we_o)
												alt_dat_oh <= mem_dat_i;
											
												mem_stb_o <= '0;
												next_state <= WAIT;
										end
							endcase
						end 
					end
			WAIT : begin
						if (~mem_cyc_i) begin
							mem_adr_o <= '0;
							mem_we_o <= '1;
							alt_ack_o <= '1;
							next_state <= PAUSE;
						end
					end
			PAUSE : begin
						alt_ack_o <= '0;
						next_state <= IDLE;
					end
		endcase
		
		end
	end
	
	endmodule

`endif