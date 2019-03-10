


module fill_rect_2d
#(
	parameter
		COLORW		= 16,
		RANGEW		= 9,
		ADDRW			= 18
)
(
	input logic 							clk_i,
	input logic 							trig_i,
	input logic 							rst_i,
	
	input logic[COLORW - 1 : 0]		color,
	input logic[RANGEW - 1 : 0]		x0, y0,
	input logic[RANGEW - 1 : 0]		width, height,
	input logic[RANGEW - 1 : 0]		leg,
	
	output logic[ADDRW - 1 : 0] 		adr_o,
	output logic[COLORW - 1 : 0]		dat_o,
	output logic							we_o,
												stb_o,
												
	output logic[1 : 0]					sel_o,
	
	input logic								cyc_i,
												ack_i,
	
	output logic 							cyc_o,
	output logic 							irq,
	input logic 							irq_clear
	
);


	localparam [1 : 0] 
		MEM_IDLE			= 0,
		MEM_PRELOAD		= 1,
		MEM_WRITE		= 2,
		MEM_WAIT			= 3;
		
	logic[1 : 0] 	mem_state = MEM_IDLE, 
						mem_next_state = MEM_IDLE;
	
	logic[ADDRW - 1 : 0] dest_adr 	= '0;
	logic[RANGEW : 0] 		dest_y 	= '0, 
									dest_x 	= '0;
	
	
	/*memory fsm*/
	
	wire[RANGEW - 1 : 0] step = leg;
	
	always_comb
		mem_state = mem_next_state;
	
	always_ff @ (posedge clk_i) begin
		if (rst_i || (dest_x == width)) begin
			stb_o		 			<= '0;
			we_o					<= '1;
			sel_o					<= '1;
			dest_y 				<= '0;
			dest_x 				<= '0;
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
								dest_adr <= x0 * step + y0;
								dest_y <= '0;
								dest_x <= '0;
								mem_next_state <= MEM_WRITE;
							end else begin
								cyc_o <= '0;
							end
						end
			MEM_PRELOAD : begin
							adr_o <= '0;
							dat_o <= '0;
							sel_o <= '1;
							if (dest_y < height) begin
								dest_y <= dest_y + 1'b1;
							end else begin
								dest_y <= '0;
								dest_x <= dest_x + 1'b1;
								dest_adr <= dest_adr + step;
							end
							
							mem_next_state <= MEM_WRITE;
						end
			MEM_WRITE : begin
							if (~cyc_i) begin
								sel_o <= '0;
								stb_o <= '1;
								adr_o <= dest_adr + dest_y;
								dat_o <= color;
								
								mem_next_state <= MEM_WAIT;
							end 
						end
			MEM_WAIT : begin
							stb_o <= '0;
							if (ack_i) begin
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
