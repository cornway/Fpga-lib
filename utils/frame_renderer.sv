



module frame_renderer
#(
	parameter	
		RANGE = 9, 
		ADDW = 18,
		DBUS = 16
)
(
	input logic 						clk_i,
	input logic							rst_i,
	input logic 						update,
	input logic[RANGE - 1 : 0] 	width,
	input logic[RANGE - 1 : 0]		height,
	
	input logic[DBUS - 1 : 0]		dat_i,
	input logic[ADDW - 1 : 0] 		adr_i,
	output logic[ADDW - 1 : 0] 	adr_o,
	output logic 						stb_o,
											we_o,
											
	output logic[DBUS - 1 : 0]		qvga_dat_o,
	output logic						qvga_pclk_o,
											qvga_reset,
	
	input logic							qvga_cyc_i,
	input logic 						mem_cyc_i,
											mem_ack_i,
	
	output logic[1 : 0] 				sel_o,
	output logic 						cyc_o,
	output logic						irq,
	input  logic						irq_clear
					
);

	
	
	logic[RANGE - 1 : 0] dot_count = '0;
	logic[RANGE - 1 : 0] line_count = '0;
	
	logic mem_rdreq = '0;
	
	logic mem_data_ready = '0;
	
	logic[DBUS - 1 : 0] mem_data_buf = '0;
	
	
	/*memory fsm*/
	logic[ADDW - 1: 0] adr_reg;
	logic qvga_frame_end = '0;
	logic mem_cyc;
	
	localparam [1 : 0]
		MEM_IDLE			= 0,
		MEM_READ			= 1,
		MEM_WAIT_ACK	= 2;

	logic[1 : 0] mem_state = MEM_IDLE, mem_next_state = MEM_IDLE;
	
	always_comb
		mem_state = mem_next_state;
	
	always_ff @ (posedge clk_i) begin
		if (rst_i | qvga_frame_end | update) begin
			mem_data_ready <= '0;
			adr_reg <= adr_i;
			stb_o <= '0;
			we_o <= '1;
			sel_o <= '1;
			adr_o <= '0;
			mem_cyc <= '0;
			if (update)
				mem_next_state <= MEM_READ;
			else 
				mem_next_state <= MEM_IDLE;
		end 
		else
		begin
		
		case (mem_state)
			MEM_IDLE : begin
							if (mem_rdreq & ~mem_cyc_i) begin
								mem_cyc <= '1;
								stb_o <= '1;
								we_o <= '0;
								sel_o <= '0;
								adr_o <= adr_reg;
								mem_data_ready <= '0;
								mem_next_state <= MEM_WAIT_ACK;
							end else begin
								mem_cyc <= '0;
							end
						end
			MEM_READ : begin	
							if (~mem_cyc_i) begin
								mem_cyc <= '1;
								stb_o <= '1;
								we_o <= '0;
								sel_o <= '0;
								adr_o <= adr_reg;
								
								mem_next_state <= MEM_WAIT_ACK;	
							end 
						end
			MEM_WAIT_ACK : begin
							stb_o <= '0;
							if (mem_ack_i) begin
								we_o <= '1;
								sel_o <= '1;
								adr_o <= '0;
								mem_data_buf <= dat_i;
								adr_reg <= adr_reg + 1'b1;
								mem_data_ready <= '1;
								
								mem_next_state <= MEM_IDLE;
							end 
						end
		endcase
		
		end /*rst_i | qvga_frame_end*/
	end
	/*memory fsm*/
	
	/*tft fsm*/
	
	localparam [1 : 0]
		QVGA_IDLE			= 0,
		QVGA_WRITE			= 1,
		QVGA_WAIT_ACK		= 2,
		QVGA_WAIT			= 3;

	logic[1 : 0] qvga_state = QVGA_IDLE, qvga_next_state = QVGA_IDLE;
	
	logic frame_busy = '0;
	
	
	always_comb
		qvga_state = qvga_next_state;
	
	always_ff @ (posedge clk_i) begin
		if (rst_i) begin
			qvga_frame_end <= '0;
			frame_busy <= '0;
			qvga_reset <= '1;
			qvga_pclk_o <= '0;
			mem_rdreq <= '0;
			dot_count <= '0;
			line_count <= '0;
			qvga_dat_o <= '0;					
			qvga_next_state <= QVGA_WAIT_ACK;
		end
		else
		begin
	
		if (mem_cyc)
			mem_rdreq <= '0;
	
		case (qvga_state)
			QVGA_IDLE : begin
							qvga_reset <= '0;
							if (mem_data_ready) begin
								frame_busy <= '1;
							
								qvga_next_state <= QVGA_WRITE;
							end else begin
								qvga_pclk_o <= '0;
								
								qvga_next_state <= QVGA_IDLE;
							end
						end
			QVGA_WRITE : begin
								qvga_dat_o <= mem_data_buf;
								if (line_count < width) begin
									if (dot_count < height) begin
										dot_count <= dot_count + 1'b1;
									end else begin
										dot_count <= '0;
										line_count <= line_count + 1'b1;
									end
									qvga_pclk_o <= '1;
									mem_rdreq <= '1;
								end else begin
										line_count <= '0;
										qvga_reset <= '1;
										qvga_frame_end <= '1;
								end			
							
								qvga_next_state <= QVGA_WAIT_ACK;
						end
			QVGA_WAIT_ACK : begin
							if (qvga_cyc_i) begin;
								qvga_reset <= '0;	
								qvga_pclk_o <= '0;
								
								qvga_next_state <= QVGA_WAIT;
							end 
						end
			QVGA_WAIT : begin
							if (~qvga_cyc_i) begin
								if (qvga_frame_end) begin
									qvga_frame_end <= '0;
									frame_busy <= '0;
								end
								qvga_next_state <= QVGA_IDLE;
							end 
						end
		endcase
		
		end /*rst_i*/
	end
	
	assign cyc_o = mem_cyc_i | frame_busy;
	
	always_ff @ (negedge frame_busy, posedge irq_clear) begin
		if (~frame_busy)
			irq = '1;
		else if (irq_clear)
			irq = '0;
	end
	
	/*tft fsm*/
	
endmodule
