`ifndef TFT_IMPL
`define TFT_IMPL




module qvga_controller
  (
		input logic clk_i,
		input logic pclk_i,
		input logic rst_i,
	 
		output logic pclk_o,
		output logic hclk_o,
		output logic vclk_o,
		output logic den_o,
		output logic cyc_o
  );
  
  parameter 
    WIDTH = '0,
    HEIGHT = '0;
  
  logic[8 : 0] line,
					dot;
					
	logic[3 : 0] seq;
					
	logic ptrig,
			htrig,
			vtrig;
			
	logic pbusy,
			hbusy,
			vbusy;
  
  
  
  pulse_p #(4) pixel_pulse
	(
		.clk_i			(clk_i),
		.trig_i			(ptrig),
		.count			(seq),
		.plow				(8'd1),
		.phi				(8'd1),
		.idle				('0),
		.sig_o			(pclk_o),
		.cyc_o			(pbusy)
	);
	
	
  pulse_p #(8) hs_pulse
	(
		.clk_i		(clk_i),
		.trig_i		(htrig),
		.count		(8'd0),
		.plow			(8'd32),
		.phi			(8'd32),
		.idle			('1),
		.sig_o		(hclk_o),
		.cyc_o		(hbusy)
	); 
	
  
  pulse_p #(8) vs_pulse
	(
		.clk_i		(clk_i),
		.trig_i		(vtrig),
		.count		(8'd0),
		.plow			(8'd32),
		.phi			(8'd128),
		.idle			('1),
		.sig_o		(vclk_o),
		.cyc_o		(vbusy)
	); 
  
  localparam [2 : 0]
		IDLE			= 0,
		PSET			= 1,
		PWAIT			= 2,
		HSET			= 3,
		HWAIT			= 4,
		WSET			= 5,
		WWAIT			= 6;
		
	logic[2 : 0] 	q_state = IDLE,
						q_next_state = IDLE;
						
						
	always_comb
		q_state = q_next_state;
	
	always_ff @ (posedge clk_i, posedge rst_i) begin
		if (rst_i) begin
			line <= 0;
			dot <= 0;
			ptrig <= '0;
			htrig <= '0;
			vtrig <= '0;
			cyc_o <= '1;
			
			q_next_state <= WSET;
		end 
		else 
		begin
		
			unique case (q_state)
					IDLE : 
					begin
								if (pclk_i) begin
									cyc_o <= '1;
									if (line < (WIDTH - 1'b1)) begin
										if (dot < (HEIGHT - 1'b1)) begin
											dot <= dot + 1'b1;
											q_next_state <= PSET;
										end else begin
											line <= line + 1'b1;
											dot <= '0;
											q_next_state <= HSET;
										end
									end else begin
										line <= '0;
										q_next_state <= WSET;
									end
								end else begin
									cyc_o <= '0;
								end
					end
					PSET : 
					begin
								seq <= '0;
								ptrig <= '1;
								q_next_state <= PWAIT;
					end
					PWAIT : 
					begin
								ptrig <= '0;
								if (~pbusy) begin
									q_next_state <= IDLE;
								end
					end
					HSET : 
					begin
								htrig <= '1;
								ptrig <= '1;
								seq <= 4'd2;
								q_next_state <= HWAIT;
					end
					HWAIT : 
					begin
								htrig <= '0;
								ptrig <= '0;
								if (~hbusy & ~pbusy) begin
									
									q_next_state <= IDLE;
								end
					end
					WSET : 
					begin
								vtrig <= '1;
								ptrig <= '1;
								seq <= 4'd15;
								q_next_state <= WWAIT;
					end
					WWAIT : 
					begin
								vtrig <= '0;
								ptrig <= '0;
								if (~vbusy & ~pbusy) begin
									
									q_next_state <= IDLE;
								end
					end
			endcase
			
		end
	end
  
	assign den_o = ~(hbusy | vbusy);
  
endmodule

`endif /*TFT_IMPL*/