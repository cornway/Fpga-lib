


module psram_asynch
#(
	parameter
		DATAW		= 16,
		ADRW		= 18
)
(
	input logic 						clk_i,
											rst_i,
	
	input logic[3 : 0] 				dat_setup, 
											adr_setup,
											da_hold,
					
										
	input logic 						we_i, 
											stb_i,
											
	output logic 						ack_o,
	
	output logic 						ce_o, 
											we_o, 
											oe_o,
											
	output logic 						cyc_o
);

	localparam [1 : 0]
		IDLE		= 0,
		ASETUP	= 1,
		DSETUP	= 2;

	logic[4 : 0] 	dsetup = '0, 
						asetup = '0;
							
	logic[1 : 0] 	state = IDLE, 
						next_state = IDLE;
	
	always_comb
		state = next_state;
	
	always_ff @ (posedge clk_i) begin
		if (rst_i) begin
			we_o <= '1;
			oe_o <= '1;
			ce_o <= '1;
			ack_o <= '0;
			cyc_o <= '0;
			next_state <= IDLE;
		end
		else 
		begin
		
		case (state)
			IDLE : begin
						ack_o <= '0;
						if (stb_i) begin	
							dsetup <= dat_setup;
							asetup <= adr_setup;
							ce_o <= '0;
							oe_o <= we_i;
							cyc_o <= '1;
							next_state <= ASETUP;
						end else begin
							cyc_o <= '0;
							oe_o <= '1;
							we_o <= '1;
							ce_o <= '1;
						end
					end
			ASETUP : begin
						if (asetup) begin
							asetup <= asetup - 1'b1;
						end else begin	
							we_o <= ~we_i;	
							next_state <= DSETUP;				
						end
					end
			DSETUP : begin
						
						if (dsetup) begin
							dsetup = dsetup - 1'b1;	
						end else begin
							ack_o <= '1;
							next_state <= IDLE;
						end	
					end
		endcase
		
		end /*rst_i*/
	end
	
endmodule

