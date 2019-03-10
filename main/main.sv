

`define SOC_V1_1




	
module main
   (
      input logic       	clock_200MHz,
      
      input logic          fsmc_oe,
      input logic          fsmc_we,
      input logic          fsmc_ce,
      output logic         fsmc_wait,
      input logic [1 : 0]  fsmc_nbl,
      input logic          fsmc_nadv,
      
      inout[15 : 0]        fsmc_da,
		input logic[2 : 0]	fsmc_addr_hi,
      
      output logic         sram_oe,
      output logic         sram_we,
      output logic         sram_ce,
      output logic[1 : 0]  sram_nbl,
      
      output logic[17 : 0] sram_addr,
      inout [15 : 0]       sram_data,
      
      
      output logic         tft_mosi,
      input logic         	tft_miso,
      output logic         tft_sck,
      output logic         tft_cs,
      output logic         tft_reset,
      
      output logic         tft_vs,
      output logic         tft_hs,
      output logic         tft_clk,
      output logic         tft_den,
      
      output logic[4 : 0]  tft_r,
      output logic[5 : 0]  tft_g,
      output logic[4 : 0]  tft_b,
      
      output logic         sys_wait,
      output logic         sys_irq
   );
	
	parameter	RANGE = 12;
	parameter	DATW = 16;
	parameter	ADRW = 18;
	parameter	TFT_WIDTH = 480;
	parameter	TFT_HEIGHT = 320;
	
   logic por;
	
	por_core
	#(64)
	upor
		(
			.clk_i(clock_200MHz),
			.por(por)
		);
	
   logic 
			clock_100MHz 	= '0, 
			clock_50MHz 	= '0,
			clock_25MHz 	= '0,
			clock_12_5MHz 	= '0,
			clock_6MHz 		= '0,
			clock_3MHz 		= '0,
			clock_1_5MHz 	= '0,
			clock_750KHz 	= '0,
			clock_375KHz 	= '0,
			clock_180KHz 	= '0,
			clock_90KHz 	= '0,
			clock_45KHz 	= '0,
			clock_22KHz 	= '0,
			clock_11KHz 	= '0;
			
	clock_core clock_core_hs
		(
			.clock(clock_200MHz),
			.clock_ena('1),
			.div_2(clock_100MHz),
			.div_4(clock_50MHz),
			.div_8(clock_25MHz),
			.div_16(clock_12_5MHz),
			.div_32(clock_6MHz),
			.div_64(clock_3MHz),
			.div_128(clock_1_5MHz)
		);
		
	clock_core clock_core_ls
		(
			.clock(clock_1_5MHz),
			.clock_ena('1),
			.div_2(clock_750KHz),
			.div_4(clock_375KHz),
			.div_8(clock_180KHz),
			.div_16(clock_90KHz),
			.div_32(clock_45KHz),
			.div_64(clock_22KHz),
			.div_128(clock_11KHz)
		);
		
`include "main_defs.sv"
		
	
	
			logic spi_start = '0, 
					spi_reset = '1,
					spi_busy;
			
			logic[2 : 0] spi_error;
			logic[4 : 0] spi_prescaler;
			logic[3 : 0] spi_data_count;
			
			logic spi_cpol,
					spi_cpha,
					spi_dir;
			
			logic[15 : 0] 	spi_out, 
								spi_in;
								
								
			spi_16bit_master tft_spi
				(
					.clock         (clock_12_5MHz),
					.port_trigger  (spi_start),
					.prescaler     (spi_prescaler),
					.data_count    (spi_data_count),
					.cpol       	(spi_cpol),
					.cpha       	(spi_cpha),
					.dir        	(spi_dir),
					.data_out      (spi_out),
					.data_in			(spi_in),
					.port_busy     (spi_busy),
					.port_sck      (tft_sck),
					.port_in    	(tft_miso),
					.port_out      (tft_mosi),
					.port_cs    	(tft_cs),
					.port_reset    (spi_reset | por),
					.error         (spi_error)
				);
		
		logic qvga_busy,
				qvga_pclk = '0,
				qvga_reset = '1;
							
      qvga_controller 
		#(
			.WIDTH(TFT_WIDTH), 
			.HEIGHT(TFT_HEIGHT)
		) rgb_controller
         (
            .clk_i            	(clock_200MHz),
            .pclk_i           	(qvga_pclk),
            .rst_i            	(qvga_reset | por),
            .cyc_o             	(qvga_busy),
            .pclk_o             	(tft_clk),
            .hclk_o             	(tft_hs),
            .vclk_o             	(tft_vs),
            .den_o              	(tft_den)
         );
      
		
		
		
		
		logic[RANGE - 1 : 0] 	gpu_dest_x = 9'd10,
							gpu_dest_y = 9'd10,
							gpu_dest_w = 9'd10,
							gpu_dest_h = 9'd10,
							gpu_dest_leg = 9'd10,
							gpu_src_x = 9'd10,
							gpu_src_y = 9'd10,
							gpu_src_w = 9'd10,
							gpu_src_h = 9'd10,
							gpu_src_leg = 9'd10;
		logic[DATW - 1 : 0]	gpu_scale_x = '0,
									gpu_scale_y = '0;
		logic[DATW - 1 : 0] 	gpu_color;
		logic[ADRW - 1 : 0] 	gpu_src_p = '0,
									gpu_dest_p = '0;
		
		
		

		logic[DATW - 1 : 0] mem_dat_o;
		logic mem_cyc_o,
				mem_ack_o;
		
		
		logic rend_rst_i = '1,
				rend_trig_i = '0;
				
		logic rend_cyc_o;
							
		logic[1 : 0] rend_sel_o;					
		logic[ADRW - 1 : 0] rend_adr_o;
		
		logic rend_stb_o,
				rend_we_o;
				
		logic rend_irq_o,
				rend_irq_clr_i;
				
		
		
		frame_renderer 
		#(
			.RANGE(RANGE), 
			.ADDW(ADRW),
			.DBUS(DATW)
		) fr
		(
				.clk_i				(clock_200MHz),
				.rst_i				(rend_rst_i | por),
				.update				(rend_trig_i),
				.width				(TFT_WIDTH),
				.height				(TFT_HEIGHT),
	
				.dat_i				(mem_dat_o),
				.adr_i				(gpu_src_p),
				.adr_o				(rend_adr_o),
				.stb_o				(rend_stb_o),
				.we_o					(rend_we_o),
											
				.qvga_dat_o			({tft_r, tft_g, tft_b}),
				.qvga_pclk_o		(qvga_pclk),
				.qvga_reset			(qvga_reset),
	
				.qvga_cyc_i			(qvga_busy),
				.mem_cyc_i			(mem_cyc_o),
				.mem_ack_i			(mem_ack_o),
	
				.sel_o				(rend_sel_o),
				.cyc_o				(rend_cyc_o),
				.irq					(rend_irq_o),
				.irq_clear			(rend_irq_clr_i)
		);
		
		
		
		logic fill_trig_i = '0,
				fill_rst_i = '1;
		
		logic[1 : 0] fill_sel_o;
		logic[ADRW - 1 : 0] 	fill_adr_o;
		logic[DATW - 1 : 0] 	fill_dat_o;
		
		logic fill_stb_o,
				fill_we_o,
				fill_cyc_o,
				fill_irq_o,
				fill_irq_clr_i;
				
				
		
		
		fill_rect_2d 
		#(
			.COLORW(DATW),
			.RANGEW(RANGE),
			.ADDRW(ADRW)
		)
		filler0
			(
				.clk_i			(clock_200MHz),
				.trig_i			(fill_trig_i),
				.rst_i			(fill_rst_i | por),
				.color			(gpu_color),
				.x0				(gpu_dest_x),
				.y0				(gpu_dest_y),
				.width			(gpu_dest_w),
				.height			(gpu_dest_h),
				.leg				(gpu_dest_leg),
				.adr_o			(fill_adr_o),
				.dat_o			(fill_dat_o),
				.we_o				(fill_we_o),
				.stb_o			(fill_stb_o),
				.sel_o			(fill_sel_o),
				.cyc_i			(mem_cyc_o),
				.ack_i			(mem_ack_o),
				.cyc_o			(fill_cyc_o),
				.irq				(fill_irq_o),
				.irq_clear		(fill_irq_clr_i)
			);
			
			
			logic	copy_rst_i = '1,
					copy_stb_o,
					copy_we_o,
					copy_cyc_o,
					copy_cyc_i,
					copy_ack_i,
					copy_trig_i = '0,
					copy_irq_o,
					copy_irq_clr_i;
					
			logic[1 : 0] copy_sel_o;
			logic[ADRW - 1 : 0] 	copy_adr_o;
			logic[DATW - 1 : 0] 	copy_dat_o,
								copy_dat_i;
								
			logic	copy_mir_x = '0,
					copy_mir_y = '1,
					copy_swap = '0,
					copy_interlace_x = '0,
					copy_interlace_y = '0;
					
			logic[DATW - 1 : 0] cs_color_in;
			logic[1 : 0] cs_mode_i = '0;
			
			color_switch
			#(
				.COLORW(DATW)
			) cs
				(
					.clk_i(clock_200MHz),
					.rst_i(por),
					.mode(cs_mode_i),
					.color_in(cs_color_in),
					.color_out(copy_dat_o)
				);
			
			copy_2d 
			#(
					.DATW(DATW),
					.ADRW(ADRW),
					.RANGEW(RANGE)
			)
			scaler
				(
					.clk_i		(clock_200MHz),
					.rst_i		(por | copy_rst_i),
					.trig_i		(copy_trig_i),
					.stb_o		(copy_stb_o),
					.we_o			(copy_we_o),
					.cyc_o		(copy_cyc_o),
					.sel_o		(copy_sel_o),
					.ack_i		(copy_ack_i),
					.cyc_i		(copy_cyc_i),
					.dat_i		(copy_dat_i),
					.dat_o		(cs_color_in),
					.adr_o		(copy_adr_o),
					.dest_x0		(gpu_dest_x),
					.dest_y0		(gpu_dest_y),
					.dest_w		(gpu_dest_w),
					.dest_h		(gpu_dest_h),
					.dest_leg	(gpu_dest_leg),
					.src_x0		(gpu_src_x),
					.src_y0		(gpu_src_y),
					.src_w		(gpu_src_w),
					.src_h		(gpu_src_h),
					.src_leg		(gpu_src_leg),
					.scale_x		(gpu_scale_x),
					.scale_y		(gpu_scale_y),
					.mask			(gpu_color),
					.mir_x		(copy_mir_x),
					.mir_y		(copy_mir_y),
					.swap			(copy_swap),
					.interlace_x(copy_interlace_x),
					.interlace_y	(copy_interlace_y),
					.src_point	(gpu_src_p),
					.dest_point	(gpu_dest_p),
					.irq			(copy_irq_o),
					.irq_clear	(copy_irq_clr_i)
				);
		
		logic ppu_rst_i = '1,
				ppu_source = '0,
				ppu_stb_o,
				ppu_we_o;
		logic[1 : 0] ppu_sel_o;
		logic[ADRW - 1 : 0] ppu_adr_o;
		
		logic[7 : 0] 	ppu_amp_Y,
							ppu_amp_C;	
		
		ppu_switch
		#(
			.DATW(DATW),
			.ADRW(ADRW)
		) ppusw
			(
				.clk_i(clock_200MHz),
				.rst_i(por | copy_rst_i | ppu_rst_i | ~tft_hs),
				.select(ppu_source),
				.mem_stb_o(ppu_stb_o),
				.mem_we_o(ppu_we_o),
				.mem_cyc_i(mem_cyc_o),
				.mem_ack_i(mem_ack_o),
				.mem_sel_o(ppu_sel_o),
				.mem_dat_i(mem_dat_o),
				.mem_adr_o(ppu_adr_o),
				
				.mas_stb_i(copy_stb_o),
				.mas_we_i(copy_we_o),
				.mas_cyc_o(copy_cyc_i),
				.mas_ack_o(copy_ack_i),
				.mas_sel_i(copy_sel_o),
				.mas_dat_o(copy_dat_i),
				.mas_adr_i(copy_adr_o),
				
				.amp_Y(ppu_amp_Y),
				.amp_C(ppu_amp_C)
			);
			
		
		logic system_select;
		
		logic fsmc_ack_i,
				fsmc_stb_o,
				fsmc_we_o,
				fsmc_sram_wait;
				
		logic[DATW - 1 : 0]	fsmc_dat_i,
									fsmc_dat_o;
							
		logic[ADRW - 1 : 0]	fsmc_adr_o;
		
		logic[3 : 0] 	psram_dlat = 4'd1,
							psram_adlat = 4'd1,
							psram_dahold = 4'd1;
		
		sram_crossbar
		sram_cossbar_switch
			(
				.clk_i			(clock_200MHz),
				.rst_i			(por),
				.fsmc_ce_i		(fsmc_ce),
				.fsmc_we_i		(fsmc_we),
				.fsmc_oe_i		(fsmc_oe),
				.fsmc_al_i		(fsmc_nadv),
				.fsmc_ack_i		(fsmc_ack_i),
				.fsmc_sel_i		(fsmc_nbl),
				.fsmc_we_o		(fsmc_we_o),
				.fsmc_stb_o		(fsmc_stb_o),
				.fsmc_adr_i		(fsmc_addr_hi),
				.fsmc_dat_io	(fsmc_da),
				.fsmc_dat_i		(fsmc_dat_i),
				.fsmc_dat_o		(fsmc_dat_o),
				.fsmc_adr_o		(fsmc_adr_o),
				.fsmc_wait		(fsmc_sram_wait),
				
				.psram_dlat		(psram_dlat),
				.psram_adlat	(psram_adlat),
				.psram_dahold	(psram_dahold),
				
				.psram_we_i		(
										rend_we_o 	&
										fill_we_o 	&
										ppu_we_o
									),
				.psram_stb_i	(
										rend_stb_o 	| 
										fill_stb_o	|
										ppu_stb_o
									),
				.psram_sel_i	(
										rend_sel_o 	& 
										fill_sel_o 	& 
										ppu_sel_o
									),
				.psram_dat_i	(
										copy_dat_o 	| 
										fill_dat_o
									),
				.psram_dat_o	(mem_dat_o),
				.psram_adr_i	(
										rend_adr_o 		| 
										fill_adr_o	|
										ppu_adr_o 	
									),
				
				.sram_ce_o		(sram_ce),
				.sram_we_o		(sram_we),
				.sram_oe_o		(sram_oe),
				.sram_sel_o		(sram_nbl),
				.sram_adr_o		(sram_addr),
				.sram_dat_io	(sram_data),
				
				.cyc_o			(mem_cyc_o),
				.ack_o			(mem_ack_o),
				
				.ss_o				(system_select)
			);
		
		
		logic sensor_trig_i = '0;
		logic sensor_rst_i = '1;
		logic sensor_dat_i = '0;
		logic[5 : 0] sensor_timeout = '0;
		logic[5 : 0] sensor_hold	 = '0;
		logic[2 : 0] sensor_state;
		logic[7 : 0] sensor_clicks;
		logic sensor_event;
		tsc_state_mach sensor_mcu
			(
				.trig_i		(sensor_trig_i),
				.rst_i		(por | sensor_rst_i),
				.dat_i		(sensor_dat_i),
				.timeout_i	(sensor_timeout),
				.hold_time_i(sensor_hold),
				.dat_o		(sensor_state),
				.clicks_o	(sensor_clicks),
				.event_o		(sensor_event),
			);
		
		
		always_latch
			if (~fsmc_we_o)
					case (fsmc_adr_o[15 : 0])
						`READ_STATUS : 
						begin
							fsmc_dat_i = {13'd0, 3'b111};
						end
						`READ_ID : 
						begin
							fsmc_dat_i = 16'hff01;
						end
						`READ_DREGA : 
						begin
							fsmc_dat_i = {
								3'd0,
								spi_reset,
								spi_data_count,
								spi_prescaler,
								spi_dir,
								spi_cpha,
								spi_cpol
							};
						end
						`READ_DREGB : 
						begin
							fsmc_dat_i = {12'd0, spi_error, spi_busy};
						end
						`READ_DREGC : 
						begin
							fsmc_dat_i = spi_in;
						end
						`READ_FR_STAT : 
						begin
							fsmc_dat_i = {14'd0, rend_cyc_o, rend_rst_i};
						end
						`READ_FILL_STAT : 
						begin
							fsmc_dat_i = {14'd0, fill_cyc_o, fill_rst_i};
						end
						`READ_COPY_STAT : 
						begin
							fsmc_dat_i = {14'd0, copy_cyc_o, copy_rst_i};
						end
						`READ_BUSY : 
						begin
							fsmc_dat_i = {13'd0, copy_cyc_o, fill_cyc_o, rend_cyc_o};
						end
						`READ_IRQS : 
						begin
							fsmc_dat_i = {13'd0, copy_irq_o, fill_irq_o, rend_irq_o};
						end
						`READ_AMP_CY : 
						begin
							fsmc_dat_i[7 : 0] = ppu_amp_C;
							fsmc_dat_i[15 : 8] = ppu_amp_Y;
						end
						`READ_TOUCH_STATE : 
						begin
							fsmc_dat_i[0] = sensor_event;
							fsmc_dat_i[3 : 1] = sensor_state;
							fsmc_dat_i[15 : 8] = sensor_clicks;
						end
						default :
						begin
							fsmc_dat_i = 16'h10ff;
						end
					endcase
		
		always_ff @ (posedge clock_200MHz)  
		begin
		
			if (fsmc_stb_o) begin
				fsmc_ack_i <= '1;
				if (system_select & fsmc_we_o) 
				begin
					case (fsmc_adr_o[15 : 0])
						`WRITE_DREGA : 
						begin
							spi_reset <= fsmc_dat_o[12];
							spi_data_count <= fsmc_dat_o[11 : 8];
							spi_prescaler <= fsmc_dat_o[7 : 3];
							spi_dir <= fsmc_dat_o[2];
							spi_cpha <= fsmc_dat_o[1];
							spi_cpol <= fsmc_dat_o[0];
					
						end
						`WRITE_DREGB : 
						begin
							spi_out <= fsmc_dat_o;
							spi_start <= '1;
						end
						`WRITE_DREGC : 
						begin
							tft_reset <= fsmc_dat_o[0];
						end
						`WRITE_FR_CTL : 
						begin
							rend_rst_i <= fsmc_dat_o[0];
							rend_trig_i <= fsmc_dat_o[1];
							//copy_rst_i <= '0;
							//copy_trig_i <= '1;
						end
						`WRITE_GPU_COLOR : gpu_color <= fsmc_dat_o;
						`WRITE_GPU_DEST_X : gpu_dest_x <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_DEST_Y : gpu_dest_y <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_DEST_W : gpu_dest_w <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_DEST_H : gpu_dest_h <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_DEST_LEG : gpu_dest_leg <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_SRC_X : gpu_src_x <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_SRC_Y : gpu_src_y <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_SRC_W : gpu_src_w <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_SRC_H : gpu_src_h <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_SRC_LEG : gpu_src_leg <= fsmc_dat_o[RANGE - 1 : 0];
						`WRITE_GPU_SCALEX : gpu_scale_x <= fsmc_dat_o;
						`WRITE_GPU_SCALEY : gpu_scale_y <= fsmc_dat_o;
						`WRITE_GPU_DPL : gpu_dest_p[15 : 0] <= fsmc_dat_o;
						`WRITE_GPU_DPH : gpu_dest_p[17 : 16] <= fsmc_dat_o[1 : 0];
						`WRITE_GPU_SPL : gpu_src_p[15 : 0] <= fsmc_dat_o;
						`WRITE_GPU_SPH : gpu_src_p[17 : 16] <= fsmc_dat_o[1 : 0];						
						`WRITE_FILL_CTL : 
						begin
							{fill_trig_i, fill_rst_i} <= fsmc_dat_o[1 : 0];
						end
						
						`WRITE_COPY_CTL : 
						begin
							{
								ppu_rst_i,
								ppu_source,
								copy_trig_i, 
								copy_rst_i
							} <= fsmc_dat_o[3 : 0];
							copy_mir_x <= fsmc_dat_o[14];
							copy_mir_y <= fsmc_dat_o[15];
							copy_swap <= fsmc_dat_o[13];
							copy_interlace_x <= fsmc_dat_o[12];
							copy_interlace_y <= fsmc_dat_o[11];
							
						end
						
						`WRITE_CS_CTL : 
						begin
							cs_mode_i <= fsmc_dat_o[1 : 0];
						end
						
						`WRITE_IRQS_CLR : 
						begin
							{
								copy_irq_clr_i,
								fill_irq_clr_i,
								rend_irq_clr_i
							} <= fsmc_dat_o[2 : 0];
						end
						
						`WRITE_PSRAM_LAT : 
						begin
							psram_adlat <= fsmc_dat_o[3 : 0];
							psram_dlat <= fsmc_dat_o[7 : 4];
							psram_dahold <= fsmc_dat_o[11 : 8];
						end
						
						`WRITE_TOUCH_CTL : 
						begin
							sensor_rst_i <= fsmc_dat_o[0];
							sensor_trig_i <= fsmc_dat_o[1];
							sensor_dat_i <= fsmc_dat_o[2];
							sensor_timeout <= fsmc_dat_o[8 : 3];
							sensor_hold <= fsmc_dat_o[14 : 9];
						end
					
						default : 
						begin
					
						end
					endcase
				
				end 
				
			end else begin
				if (rend_trig_i) rend_trig_i <= '0;
				if (fill_trig_i) fill_trig_i <= '0;
				if (copy_trig_i) copy_trig_i <= '0;
				if (spi_busy) spi_start <= '0;
				fsmc_ack_i <= '0;
			end
									
			
		end
		

		assign fsmc_wait = fsmc_sram_wait;
		assign sys_irq = rend_irq_o | copy_irq_o | fill_irq_o;
		assign sys_wait = rend_cyc_o | copy_cyc_o | fill_cyc_o;
		
		
		
endmodule
