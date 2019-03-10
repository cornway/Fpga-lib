
module por_core /*power on reset*/
#(
	parameter
		POR_CYCLES = 16
)
	(
		input logic clk_i,
		
		output logic por
	);
	
	logic[$clog2(POR_CYCLES) : 0] counter = '0;
	
	always_ff @ (posedge clk_i)
		if (counter < POR_CYCLES)
			counter = counter + 1'b1;
	
	assign por = counter < POR_CYCLES ? 1'b1 : 1'b0;
	
endmodule

module clock_core
	(
		input logic clock,
		input logic clock_ena,
		
		output logic
							div_2,
							div_4,
							div_8,
							div_16,
							div_32,
							div_64,
							div_128
	);
	
	logic[6 : 0] clock_prescaler = '0;
	
	always_ff @ (posedge clock) clock_prescaler <= clock_prescaler + 1'b1;
	
	always_comb begin
		if (clock_ena) begin
			div_2 = clock_prescaler[0];
			div_4 = clock_prescaler[1];
			div_8 = clock_prescaler[2];
			div_16 = clock_prescaler[3];
			div_32 = clock_prescaler[4];
			div_64 = clock_prescaler[5];
			div_128 = clock_prescaler[6];
		end else begin
			div_2 = '0;
			div_4 = '0;
			div_8 = '0;
			div_16 = '0;
			div_32 = '0;
			div_64 = '0;
			div_128 = '0;
		end
	end
	
endmodule

module color_switch
	#(
		parameter COLORW = 16
	)
	(
		input logic 			clk_i,
		input logic				rst_i,
		
		input logic[1 : 0]	mode,
		
		input logic[COLORW - 1 : 0] color_in,
		
		output logic[COLORW - 1 : 0] color_out
	);
		
	always_comb begin
		unique case (mode)
			2'd0 : 
			begin
						color_out = color_in;
			end
			2'd1 : 
			begin
						color_out[4 : 0] = color_in[15 : 11];
						color_out[10 : 5] = color_in[15 : 10];
						color_out[15 : 11] = color_in[15 : 11];
						
			end
			2'd2 : 
			begin
						color_out[15 : 11] = color_in[4 : 0];
						color_out[10 : 5] = color_in[10 : 5];
						color_out[4 : 0] = color_in[15 : 11];
			end
			2'd3 : 
			begin
						color_out = ~color_in;
			end
		endcase
	end
	
endmodule

module ccir_ppu
	#(
		parameter
			DATW = 16,
			ADRW = 18
	)
	(
		input logic clk_i,
		input logic rst_i,
		
		input logic stb_i,
						we_i,
						
		output logic 	cyc_o,
							ack_o,
		output logic[1 : 0] sel_o,
							
		input logic[ADRW - 1 : 0] adr_i,
		output logic[DATW - 1 : 0] dat_o,
		
		
		
		output logic 	stb_o,
							we_o,
							
		input logic		cyc_i,
							ack_i,
		input logic[1 : 0] sel_i,
							
		output logic[ADRW - 1 : 0] adr_o,
		input logic[DATW - 1 : 0] dat_i,
		
		output logic[7 : 0] 	amp_Y,
									amp_C
		
	);
	
	
	
	logic ppu_trig = '0,
			ppu_cyc;
	
	logic[7 : 0] red, green, blue;
	logic[7 : 0] Y, Cb, Cr;
	wire[7 : 0] amp;
	
	assign amp = (Cr + Cb) >> 1;
	
	yuv_rgb ppu
		(
			.clk_i(clk_i),
			.rst_i(rst_i),
			.trig_i(ppu_trig),
			.cyc_o(ppu_cyc),
			.Y_data(Y),
			.Cr_data(Cr),
			.Cb_data(Cb),
			.red_data(red),
			.green_data(green),
			.blue_data(blue)
		);
		
	localparam [2 : 0]
		IDLE		= 0,
		MEM_LOAD = 1,
		MEM_WAIT = 2,
		PPU_LOAD	= 3,
		PPU_WAIT = 4;
	
	logic[2 : 0] 	state = IDLE,
						next_state = IDLE;
	
	/*stream example : */
	/*Cb Y Cr Y Cb Y Cr Y*/
	
	logic pair;
	
						
	always_comb
		state = next_state;
		
	always_ff @ (posedge clk_i) begin
		if (rst_i) begin
			pair <= '0;
			ppu_trig <= '0;
			we_o <= '1;
			sel_o <= '1;
			stb_o <= '0;
			ack_o <= '0;
			adr_o <= '0;
			dat_o <= '0;
			cyc_o <= '0;
			next_state <= IDLE;
		end
		else
		begin	
		case (state)
			IDLE :
			begin
						ack_o <= '0;
						if (stb_i) begin
							cyc_o <= '1;
							next_state <= MEM_LOAD;
						end else begin
							cyc_o <= '0;
						end
			end
			MEM_LOAD :
			begin
						if (~cyc_i) begin
							stb_o <= '1;
							we_o <= we_i;
							sel_o <= sel_i;
							adr_o <= adr_i;
							next_state <= MEM_WAIT;
						end
			end
			MEM_WAIT :
			begin
						stb_o <= '0;
						if (ack_i) begin
							we_o <= '1;
							sel_o <= '1;
							adr_o <= '0;
							if (~pair) begin
								Cb <= dat_i[7 : 0];
							end else begin
								Cr <= dat_i[7 : 0];
							end
							Y <= dat_i[15 : 8];
							amp_Y <= (amp_Y + Y) >> 1;
							amp_C <= (amp_C + amp) >> 1;
							next_state <= PPU_LOAD;
						end
			end
			PPU_LOAD :
			begin
						if (~ppu_cyc) begin
							pair <= ~pair;
							ppu_trig <= '1;
							next_state <= PPU_WAIT;
						end
			end
			PPU_WAIT :
			begin
						ppu_trig <= '0;
						if (~ppu_cyc) begin
							dat_o[4 : 0] <= blue[7 : 4];
							dat_o[10 : 5] <= green[7 : 3];
							dat_o[15 : 11] <= red[7 : 4];
							ack_o <= '1;
							next_state <= IDLE;
						end
			end
		endcase
		end
	end
	
endmodule

module ppu_switch
	#(
		parameter
			DATW = 16,
			ADRW = 18
	)
	(
		input logic 						clk_i,
		input logic 						rst_i,
		
		input logic 						select,
		
		output logic 						mem_stb_o,
												mem_we_o,
							
		input logic							mem_cyc_i,
												mem_ack_i,
							
		output logic[1 : 0] 				mem_sel_o,
		input logic[DATW - 1 : 0] 		mem_dat_i,
		output logic[ADRW - 1 : 0] 	mem_adr_o,
		

		
		input logic 						mas_stb_i,
												mas_we_i,
							
		output logic 						mas_cyc_o,
												mas_ack_o,
		input logic[1 : 0] 				mas_sel_i,					
		output logic[DATW - 1 : 0] 	mas_dat_o,
		input logic[ADRW - 1 : 0] 		mas_adr_i,
		
		output logic[7 : 0]				amp_Y,
												amp_C
	);
	
	logic ppu_stb_i,
			ppu_we_i,
			ppu_cyc_o,
			ppu_ack_o,
			ppu_stb_o,
			ppu_we_o;
			
	logic[1 : 0] 	ppu_sel_o,
						ppu_sel_i;
	
	logic[DATW - 1 : 0] 	ppu_dat_o;
	
	logic[ADRW - 1 : 0]  ppu_adr_i,
								ppu_adr_o;

	
	ccir_ppu 
	#(
		.ADRW(ADRW),
		.DATW(DATW)
	) uppu
		(
			.clk_i(clk_i),
			.rst_i(rst_i),
			.stb_i(ppu_stb_i),
			.we_i(ppu_we_i),
			.cyc_o(ppu_cyc_o),
			.ack_o(ppu_ack_o),
			.sel_o(ppu_sel_o),
			.adr_i(ppu_adr_i),
			.dat_o(ppu_dat_o),
			
			.stb_o(ppu_stb_o),
			.we_o(ppu_we_o),
			.cyc_i(mem_cyc_i),
			.ack_i(mem_ack_i),
			.sel_i(ppu_sel_i),
			.adr_o(ppu_adr_o),
			.dat_i(mem_dat_i),
			.amp_Y(amp_Y),
			.amp_C(amp_C)
		);
	
	assign	mem_stb_o 	= select ? ppu_stb_o : mas_stb_i;
	assign 	mem_we_o 	= select ? ppu_we_o : mas_we_i;
	assign 	mem_sel_o 	= select ? ppu_sel_o : mas_sel_i;
	assign	mem_adr_o 	= select ? ppu_adr_o : mas_adr_i;
	
	assign 	ppu_stb_i 	= select ? mas_stb_i : '0;
	assign 	ppu_we_i 	= select ? mas_we_i : '1;
	assign	ppu_sel_i 	= select ? mas_sel_i : '1;
	assign 	ppu_adr_i 	= select ? mas_adr_i : '0;
	
	assign	mas_cyc_o 	= select ? ppu_cyc_o : mem_cyc_i;
	assign 	mas_ack_o 	= select ? ppu_ack_o : mem_ack_i;
	assign 	mas_dat_o 	= select ? ppu_dat_o : mem_dat_i;
	
endmodule



			
module sram_crossbar
	(
		input logic 			clk_i,
									rst_i,
		
		input logic				fsmc_ce_i,
									fsmc_we_i,
									fsmc_oe_i,
									fsmc_al_i,
									fsmc_ack_i,
									
		input logic[1 : 0]	fsmc_sel_i,
		
		output logic			fsmc_we_o,
									fsmc_stb_o,
									
		input logic[2 : 0]	fsmc_adr_i,
		
		inout[15 : 0]			fsmc_dat_io,
		
		input logic[15 : 0] 	fsmc_dat_i,
		output logic[15 : 0] fsmc_dat_o,
		output logic[17 : 0]	fsmc_adr_o,
		output logic 			fsmc_wait,
		
		input logic[3 : 0]	psram_dlat,
									psram_adlat,
									psram_dahold,
		
		input logic				psram_stb_i,
									psram_we_i,
									
		input logic[1 : 0]	psram_sel_i,
		
		input logic[15 : 0]	psram_dat_i,
		output logic[15 : 0]	psram_dat_o,
		input logic[17 : 0]	psram_adr_i,
		
		
		
		output logic			sram_ce_o,
									sram_we_o,
									sram_oe_o,
									
		output logic[1 : 0]	sram_sel_o,
		
		output logic[17 : 0] sram_adr_o,
		
		inout[15 : 0]			sram_dat_io,
		
		output logic			cyc_o,
									ack_o,
									ss_o
	);
	
	

	logic ss_ii;
	logic[15 : 0] fsmc_dat_ii;
	
	fsmc_mux_async_slave 
	fsmc_mux_async_slave_1
   (
      .clk_i					(clk_i),
      .dat_io					(fsmc_dat_io),
		.adr_hi					(fsmc_adr_i),
      .oe_i						(fsmc_oe_i),
      .we_i						(fsmc_we_i),
      .ce_i						(fsmc_ce_i),
      .al_i						(fsmc_al_i),
      .we_o						(fsmc_we_o),
      .stb_o					(fsmc_stb_o),
		.ack_i					(fsmc_ack_i),
      .adr_o					({ss_o, fsmc_adr_o}),
      .dat_i					(fsmc_dat_ii),
		.dat_o					(fsmc_dat_o)
   );
	
	logic psram_ack,
			psram_cyc,
			psram_ce,
			psram_we,
			psram_oe,
			fsmc_cyc;
	
			
	psram_asynch
	psram_asynch_1
	(
		.clk_i					(clk_i),
		.rst_i					(rst_i),
		.dat_setup				(psram_dlat),
		.adr_setup				(psram_adlat),
		.da_hold					(psram_dahold),
		.we_i						(psram_we_i),
		.stb_i					(psram_stb_i),
		.ack_o					(psram_ack),
		.ce_o						(psram_ce),
		.we_o						(psram_we),
		.oe_o						(psram_oe),
		.cyc_o					(psram_cyc)
	);
	
	
	
		localparam
			MUX_IDLE 				= 2'd0,
			MUX_FSMC_PSRAM_WAIT 	= 2'd1,
			MUX_FSMC_DO				= 2'd2;

		logic[1 : 0] 	mux_state = MUX_IDLE, 
							mux_next_state = MUX_IDLE;
		
		
		always_comb
			mux_state = mux_next_state;
		
		always_ff @ (posedge clk_i) begin
			if (rst_i) begin
				mux_next_state <= MUX_IDLE;
				fsmc_cyc <= '0;
				fsmc_wait <= '0;
			end 
			else
			begin
			
			case (mux_state)
				MUX_IDLE : begin
								if (~fsmc_ce_i & ss_ii) begin
									fsmc_wait <= '1;
									mux_next_state <= MUX_FSMC_PSRAM_WAIT;
								end else begin
									fsmc_cyc <= '0;
									fsmc_wait <= '0;
								end
								
							end
				MUX_FSMC_PSRAM_WAIT : begin
								if (~psram_cyc) begin
									fsmc_cyc <= '1;
									fsmc_wait <= '0;
									
									mux_next_state <= MUX_FSMC_DO;
								end else
									fsmc_cyc <= '0;
							end
				MUX_FSMC_DO : begin
								if (fsmc_ce_i) begin
									mux_next_state <= MUX_IDLE;
								end 
							end
			endcase
			
			end /*rst_i*/
		end
		
		
		assign sram_ce_o = fsmc_cyc ? fsmc_ce_i : psram_ce;
		assign sram_we_o = fsmc_cyc ? fsmc_we_i : psram_we;
		assign sram_oe_o = fsmc_cyc ? fsmc_oe_i : psram_oe;
		assign sram_sel_o = fsmc_cyc ? fsmc_sel_i : psram_sel_i;
		assign sram_adr_o = fsmc_cyc ? fsmc_adr_o : psram_adr_i;
		
		
		
		always_latch
			if (~psram_oe)
				psram_dat_o = sram_dat_io;
		
		assign cyc_o =  psram_cyc | fsmc_cyc;	
		assign ack_o = psram_ack;
		
		wire[15 : 0] sram_dat = psram_cyc ? psram_dat_i : fsmc_dat_o;
		
		assign sram_dat_io = ~sram_oe_o ? 'z : sram_dat;	
		
		assign fsmc_dat_ii = ss_o ? fsmc_dat_i : sram_dat_io;
								
		assign ss_ii = ~fsmc_adr_i[2];
	
endmodule


module tsc_state_mach
	(
		input logic 					trig_i,
		input logic 					rst_i,
		
		input logic[0 : 0]			dat_i,
		input logic[5 : 0]			timeout_i,
		input logic[5 : 0]			hold_time_i,
		
		output logic[2 : 0] 			dat_o,
		output logic[7 : 0]			clicks_o,
		output logic 					event_o
	);
	
	localparam[2 : 0]
		IDLE 			= 0,
		CLICK 		= 1,
		TOUCH 		= 2,
		HOLD 			= 3,
		RELEASE 		= 4,
		COOL_DOWN 	= 5;
		
	localparam[0 : 0]
		UNPRESSED = 0,
		PRESSED	 = 1;
		
	logic[2 : 0] state = IDLE, next_state = IDLE;
	logic[5 : 0] timeout = '0;
	logic[5 : 0] hold_time = '0;
	
	
	always_comb 
		state = next_state;
		
	always_ff @ (posedge trig_i, posedge rst_i) begin
		if (rst_i) begin
			timeout <= timeout_i;
			hold_time <= '0;
		end 
		else 
		begin
			case (state)
				IDLE : 
				begin
							if (dat_i == PRESSED) begin
									
								next_state <= CLICK;
							end 
							timeout <= timeout_i;
							hold_time <= '0;
							clicks_o <= '0;
							event_o <= 1'b0;
				end
				CLICK : 
				begin
							if (dat_i == UNPRESSED) begin
								event_o <= 1'b0;
								next_state <= IDLE;
							end else begin
								clicks_o <= clicks_o + 1'b1;
								event_o <= 1'b1;
								next_state <= TOUCH;
							end
				end
				TOUCH : 
				begin
							if (dat_i == PRESSED) begin
								if (hold_time < hold_time_i) begin
									hold_time <= hold_time + 1'b1;
								end else begin
									hold_time <= '0;
									next_state <= HOLD;
								end
							end else begin
								next_state <= RELEASE;
							end
				end
				HOLD : 
				begin
							if (dat_i == UNPRESSED) begin
								
								next_state <= RELEASE;
							end
				end
				RELEASE : 
				begin
							next_state <= COOL_DOWN;
							timeout <= timeout_i;
				end
				COOL_DOWN : 
				begin
							event_o <= 1'b0;
							if (dat_i == PRESSED) begin
								
								next_state <= CLICK;
							end else begin
								if (timeout) begin
									timeout = timeout - 1'b1;
								end else begin
									
									next_state <= IDLE;
								end
							end
							
				end
			endcase
		end
	end
	
	assign dat_o = state;
	
	
	
endmodule
