`ifndef __CCIR_CPU__
`define __CCIR_CPU__

typedef enum {
	yuv_luma_only,
	yuv_rgb565,
	yuv_rgb666,
	yuv_rgb888
} __YUV_MODES;


module yuv_rgb
	( 
		input logic clk_i,
		input logic rst_i,
		input logic trig_i, 
		output logic cyc_o,
		input logic[7 : 0] Y_data,
		input logic[7 : 0] Cr_data,
		input logic[7 : 0] Cb_data,
		
		output logic[7 : 0] red_data,
		output logic[7 : 0] green_data,
		output logic[7 : 0] blue_data
	);
	
	
	localparam
		IDLE		= 3'd0,
		SETUP		= 3'd1,
		STATE_1	= 3'd2,
		STATE_2	= 3'd3;
	
	logic[2 : 0] state = IDLE, next_state = IDLE;
	logic[7 : 0] Cb, Cr;
	logic[7 : 0] Cb_2;
	logic[7 : 0] Cr_3;
	logic[7 : 0] Cr_5;
	logic[7 : 0] Cr_35;
	logic[7 : 0] Gb, Gr;
	logic[7 : 0] Cr_sub, Cb_sub;
	
	
	always_comb
		state = next_state;
	
	always_ff @ (posedge clk_i) begin
		if (rst_i) begin
			Cb = '0;
			Cr = '0;
			Cb_2 = '0;
			Cr_3 = '0;
			Cr_5 = '0;
			Cr_35 = '0;
			
			next_state <= IDLE;
		end
		else
		begin
		unique case (state)
			IDLE : begin
				if (trig_i) begin
					cyc_o <= '1;
					next_state <= SETUP;
				end else begin
					cyc_o <= '0;
				end
			end
			SETUP : begin
				Cb <= Cb_data - 8'h80;
				Cr <= Cr_data - 8'h80;
				Cb_2 <= Cb_data << 2;
				Cr_3 <= Cr_data << 3;
				Cr_5 <= Cr_data << 5;
				Cr_35 <= Cr_3 + Cr_5;
				
				next_state <= STATE_1;
			end
			STATE_1 : begin
				Gb <= Cb_2 + (Cb << 4) + (Cb << 5);
				Gr <= (Cr << 1) + (Cr << 4) + Cr_35;
				Cb_sub <= (Cb << 1) + Cb_2 + Cb_2;
				Cr_sub <= (Cr << 2) + Cr_3 + Cr_5;

				next_state <= STATE_2;
			end
			STATE_2 : begin
				red_data <= Y_data + Cr + Cr_sub;
				green_data <= Y_data - (Gb - Gr);
				blue_data <= Y_data + Cb + Cb_sub;
				
				next_state <= IDLE;
			end
		endcase
		end
	end
	/*
	Cr = Cr - 128;
	Cb = Cb - 128;
	R = Y + Cr + (Cr >> 2) + (Cr >> 3) + (Cr >> 5);
	G = Y - ((Cb >> 2) + (Cb >> 4) + (Cb >> 5)) - ((Cr >> 1) + (Cr >> 3) + (Cr >> 4) + (Cr >> 5));
	B = Y + Cb + (Cb >> 1) + (Cb >> 2) + (Cb >> 2);
	
	*/
	
endmodule

/*stream example : */
/*Cb Y Cr Y Cb Y Cr Y*/


`endif /*__CCIR_CPU__*/