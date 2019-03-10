

module copy_2d
	#(
		parameter
			DATW		= 16,
			ADRW		= 18,
			RANGEW	= 9
	)
	(
		input logic 	clk_i,
							trig_i,
		input logic 	rst_i,
		
		output logic 	stb_o,
		output logic 	we_o,
		output logic	cyc_o,
		input logic 	ack_i,
		input logic 	cyc_i,
			
		
		input logic[DATW - 1 : 0]	dat_i,
		output logic[DATW - 1 : 0] dat_o,
		output logic[ADRW - 1 : 0] adr_o,
		output logic[1 : 0]			sel_o,
		
		input logic[RANGEW - 1 : 0]	dest_x0,
												dest_y0,
												dest_w,
												dest_h,
												dest_leg,
												src_x0, 
												src_y0,
												src_w,
												src_h,
												src_leg,
		input logic[DATW - 1 : 0]		scale_x,
												scale_y,
		input logic[DATW - 1 : 0]		mask,
		input logic[ADRW - 1 : 0]		src_point,
												dest_point,
												
		input logic							mir_x,
												mir_y,
												swap,
												interlace_x,
												interlace_y,
												
												
		output logic						irq,
		input logic 						irq_clear
	);
	
	localparam [2 : 0] 
		MEM_IDLE			= 0,
		MEM_PRELOAD		= 1,
		MEM_READ			= 2,
		MEM_RWAIT		= 3,
		MEM_WRITE		= 4,
		MEM_TURN			= 5;
		
	logic[2 : 0] 	mem_state = MEM_IDLE, 
						mem_next_state = MEM_IDLE;
	
	logic[RANGEW - 1 : 0] 	dest_x = '0, 
									dest_y = '0,
									src_x = '0,
									src_y = '0;
	
	
	/*memory fsm*/
	
	logic[ADRW - 1 : 0] 	dest_adr,
								src_adr;
	
	wire[RANGEW - 1 : 0] dest_step = dest_leg;
	wire[RANGEW - 1 : 0] src_step = src_leg;
	
	logic[DATW - 1 : 0] color_i;
	
	logic[7 : 0]				scale_xnom,
									scale_xdenom;
									
	logic[22 : 0]				scale_xnom_cnt,
									scale_xdenom_cnt;	
									
	logic[7 : 0]				scale_ynom,
									scale_ydenom;
									
	logic[22 : 0]				scale_ynom_cnt,
									scale_ydenom_cnt;								
									
	wire[RANGEW - 1 : 0] 	dest_y_init,
									dest_y_next,
									dest_y_skip;
	wire						dest_y_compare;
	
	wire[ADRW - 1 : 0] dest_adr_offset;
	
	assign dest_adr_offset = dest_y0 + dest_point;
			
	assign dest_y_init = mir_y ? dest_h : '0;
	assign dest_y_next = mir_y ? dest_y - 1'b1 - (interlace_y ? 1'b1 : 1'b0) : dest_y + 1'b1 + (interlace_y ? 1'b1 : 1'b0);
	assign dest_y_skip = dest_y;//mir_y ? (dest_y < scale_yi ? '0 : dest_y - scale_yi) : dest_y + scale_yi;
	assign dest_y_compare = mir_y ? (dest_y == '0 ? '1 : '0) : (dest_y >= dest_h ? '1 : '0);
	
	wire[ADRW - 1 : 0] 	dest_adr_next,
								dest_adr_init;
								
	assign dest_adr_init = mir_x ? (dest_x0 + dest_w) * dest_step + dest_adr_offset : dest_x0 * dest_step + dest_adr_offset;
	assign dest_adr_next	= mir_x ? dest_adr - dest_step - (interlace_x ? dest_step : '0) : dest_adr + dest_step + (interlace_x ? dest_step : '0);
									
	wire 	frame_end_cond,
			line_end_cond;
			
	assign frame_end_cond = swap ? (src_y >= src_h ? 1'b1 : 1'b0) : (src_x >= src_w ? 1'b1 : 1'b0);
	assign line_end_cond = swap ? (src_x >= src_w ? 1'b1 : 1'b0) : (src_y >= src_h ? 1'b1 : 1'b0);
	
	always_comb
		mem_state = mem_next_state;
		
	
	always_ff @ (posedge clk_i) begin
		if (ack_i) begin
			stb_o <= '0;
			sel_o <= '1;
			we_o <= '1;
			adr_o <= '0;
			dat_o <= '0;
		end
	
		if (rst_i || frame_end_cond || (dest_x == dest_w)) begin
			stb_o		 			<= '0;
			we_o					<= '1;
			sel_o					<= '1;
			dest_x 				<= '0;
			dest_y 				<= dest_y_init;
			src_x 				<= '0;
			src_y 				<= '0;
			cyc_o 				<= '0;
			adr_o		 			<= '0;
			dat_o		 			<= '0;
							
			mem_next_state <= MEM_IDLE;
		end
		else
		case (mem_state)
			MEM_IDLE : begin
							if (trig_i) begin
								cyc_o <= '1;
								dest_adr <= dest_adr_init;
								dest_x <= '0;
								dest_y <= dest_y_init;
								src_adr <= src_x0 * src_step + src_y0 + src_point;
								src_x <= '0;
								src_y <= '0;
								scale_xnom <= scale_x[15 : 8];
								scale_xdenom <= scale_x[7 : 0];
								scale_ynom <= scale_y[15 : 8];
								scale_ydenom <= scale_y[7 : 0];
								scale_xnom_cnt <= '0;
								scale_xdenom_cnt <= '0;
								scale_ynom_cnt <= '0;
								scale_ydenom_cnt <= '0;
								mem_next_state <= MEM_READ;
							end else begin
								cyc_o <= '0;
							end
						end
			MEM_PRELOAD : begin
							if (scale_ynom_cnt >= scale_ydenom_cnt) begin
								scale_ydenom_cnt <= scale_ydenom_cnt + scale_ydenom;
								dest_y = dest_y_next;
								mem_next_state <= MEM_TURN;
							end else begin
								if (line_end_cond | dest_y_compare) begin
									scale_ynom_cnt <= '0;
									scale_ydenom_cnt <= '0;
									dest_y <= dest_y_init;
									dest_x <= dest_x + 1'b1 + (interlace_x ? 1'b1 : 1'b0);
									dest_adr <= dest_adr_next;
									
									if (swap)
										src_x <= '0;
									else 
										src_y <= '0;
										
									if (scale_xnom_cnt >= scale_xdenom_cnt) begin
										scale_xdenom_cnt <= scale_xdenom_cnt + scale_xdenom;
									end else begin
										scale_xnom_cnt <= scale_xnom_cnt + scale_xnom;
										
										if (swap) begin
											src_y <= src_y + 1'b1;
										end else begin
											src_x <= src_x + 1'b1;
										end
										
									end
									mem_next_state <= MEM_READ;
								end else begin
									dest_y = dest_y_next;
									scale_ynom_cnt <= scale_ynom_cnt + scale_ynom;
									if (swap) begin
										src_x <= src_x + 1'b1;

									end else begin
										src_y <= src_y + 1'b1;
									end
									
									mem_next_state <= MEM_READ;
								end
							end
						end
			MEM_READ : begin
							if (~cyc_i) begin
								sel_o <= '0;
								we_o <= '0;
								stb_o <= '1;
								adr_o <= src_adr + src_y + src_step * src_x;
								
								mem_next_state <= MEM_RWAIT;
							end 
						end
			MEM_RWAIT : begin
							if (ack_i) begin
								color_i <= dat_i;
								mem_next_state <= MEM_TURN;
							end 
						end
			MEM_WRITE : begin
							if (~cyc_i) begin
								sel_o <= '0;
								we_o <= '1;
								stb_o <= '1;
								adr_o <= dest_adr + dest_y;
								dat_o <= color_i;
								
								mem_next_state <= MEM_PRELOAD;
							end 
						end
			MEM_TURN : begin
							if ((color_i != mask) || (mask == '0))
								mem_next_state <= MEM_WRITE; 
							else begin
								//dest_y <= dest_y_skip;
								//scale_yi <= 0;
								mem_next_state <= MEM_PRELOAD;
							end
						end
		endcase
	end
	
	/*memory fsm*/
	
	
	always_ff @ (negedge cyc_o, posedge irq_clear) begin
		if (~cyc_o) begin
			irq <= '1;
		end else begin
			irq <= '0;
		end
	end
	
	endmodule
	
	