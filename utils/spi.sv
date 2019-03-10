`ifndef __SPI
`define __SPI


`define LO 		'0
`define HI 		'1
`define NULL 	'0
`define HIZ		'z
`define ONE 	1'b1

`define POL_RISING			`LO
`define POL_FALLING			`HI
`define PHA_ONE_EDGE		`LO
`define PHA_TWO_EDGES		`HI
`define MSB_FIRST			`LO
`define LSB_FIRST			`HI
`define SPI_READY			`LO
`define SPI_BUSY			`HI
`define ERROR				`HI

`define SET_ERROR			`HI
`define RESET_ERROR			`LO


`define SPI_ERROR_DOUBLE_START_BP		0
`define SPI_ERROR_ZERO_DATA_BP			1
`define SPI_ERROR_SMALL_PRESCALER_BP	2	



module spi_16bit_master 
	(
		input logic 			clock,
		input logic 			port_trigger,
		input logic[4 : 0] 		prescaler,
		input logic[3 : 0] 		data_count,
		input logic 			cpol,
		input logic 			cpha,
		input logic 			dir,
		
		output logic[15 : 0]data_in,
		input logic[15 : 0] data_out,
		
		
		output logic 			port_busy,
		output logic 			port_sck,
		input logic 			port_in,
		output logic 			port_out,
		output logic 			port_cs,
		
		input logic 			port_reset,
		output logic[2 : 0] 	error
	);
	
	
	localparam
		SCK_IDLE				= 3'd0,
		SCK_SETUP			= 3'd1,
		SCK_PAUSE			= 3'd2,
		SCK_COUNT_SETUP	= 3'd3,
		SCK_COUNT_LATCH	= 3'd4,
		SCK_STOP				= 3'd5;
		
	
	logic[2 : 0] sck_state = SCK_IDLE, sck_next_state = SCK_IDLE;
	logic[5 : 0] clock_prescaler, temp_clock_prescaler;
	logic phase_count;
	logic[3 : 0] bit_count;
	logic data_mux_out;
	
	always_ff @ (posedge clock) begin
		if (port_reset) begin
			sck_state <= SCK_IDLE;
			error <= `NULL;
		end else if (port_trigger) begin
			
			if (data_count > 4'd2) begin
				error[`SPI_ERROR_ZERO_DATA_BP] <= `RESET_ERROR;
				
				if (port_busy) 
					error[`SPI_ERROR_DOUBLE_START_BP] <= `SET_ERROR;
				else begin
				
					error[`SPI_ERROR_DOUBLE_START_BP] <= `RESET_ERROR;
					
					if (prescaler < 5'd2)
						error[`SPI_ERROR_SMALL_PRESCALER_BP] <= `SET_ERROR;
					else begin
						error[`SPI_ERROR_SMALL_PRESCALER_BP] <= `RESET_ERROR;
						sck_state <= SCK_SETUP;
					end
					
				end
				
			end else /**/
				error[`SPI_ERROR_ZERO_DATA_BP] <= `SET_ERROR;
			
		end else begin
			sck_state <= sck_next_state;
		end
	end

	logic initial_latch, initial_setup;
	
	always_comb begin
		if (cpol == `POL_RISING) begin
			initial_latch = `LO;
			initial_setup = `HI;
		end else begin
			initial_latch = `HI;
			initial_setup = `LO;
		end
	end		
			
	
	logic[2 : 0] delayed_state = `NULL;	
	always_ff @ (posedge clock) begin
		case (sck_state)
			SCK_IDLE : begin
				phase_count 	= `NULL;
				bit_count 		= `NULL;
				port_sck 		= initial_latch;
				port_busy 		= `SPI_READY;
				port_out 		= `HI;
				port_cs 		= `HI;
				
				sck_next_state = SCK_IDLE;
			end
			SCK_SETUP : begin
				phase_count = cpha;	
				bit_count = data_count;
				
				clock_prescaler = prescaler >> 1;
				temp_clock_prescaler = clock_prescaler;
				port_busy = `SPI_BUSY;
				port_cs = `LO;
				
				sck_next_state = SCK_PAUSE;
				delayed_state = SCK_COUNT_SETUP;
			end
			SCK_PAUSE : begin
				if (temp_clock_prescaler) begin
					temp_clock_prescaler = temp_clock_prescaler - 1'b1;
				end else begin
					temp_clock_prescaler = clock_prescaler;
					
					sck_next_state = delayed_state;
				end
			end
			SCK_COUNT_SETUP : begin
				if (temp_clock_prescaler) begin
					temp_clock_prescaler = temp_clock_prescaler - 1'b1;
				end else begin
					if (bit_count) begin
						if (phase_count) begin
							phase_count = phase_count - 1'b1;
						end else begin
							bit_count 	= bit_count - 1'b1;
							port_out 	= data_mux_out;
						end
						
						temp_clock_prescaler 	= clock_prescaler;
						port_sck 				= initial_latch;
						sck_next_state 			= SCK_COUNT_LATCH;
					end else begin
						temp_clock_prescaler 	= clock_prescaler;
						delayed_state 			= SCK_STOP;
						sck_next_state 			= SCK_PAUSE;
					end
				end
			end
			SCK_COUNT_LATCH : begin
				if (temp_clock_prescaler) begin
					temp_clock_prescaler = temp_clock_prescaler - 1'b1;
				end else begin
					temp_clock_prescaler 	= clock_prescaler;
					port_sck 				= initial_setup;
					sck_next_state 			= SCK_COUNT_SETUP;
				end
			end
			SCK_STOP : begin
				sck_next_state = SCK_IDLE;
			end
		endcase
	end
	
	logic[3 : 0] mux_selector;
	
	always_comb
		if (dir == `MSB_FIRST)
			mux_selector = bit_count - 1'b1;
		else 
			mux_selector = data_count - bit_count;
	
	mux_16to1 mux_out
		(
			.in(data_out),
			.select(mux_selector),
			.out(data_mux_out)
		);

	logic latch_edge;
	
	always_comb
		if (cpol == `POL_RISING)
			latch_edge = port_sck;
		else 
			latch_edge = ~port_sck;
			
			
	always_ff @ (posedge latch_edge) begin
		if (phase_count == '0)
			data_in <= {data_in[14 : 0], port_in};
	end
	
endmodule

module spi_16bit_slave
	(
		input logic clock, 
		input logic port_sck, 
		input logic port_mosi, 
		input logic port_cs, 
		output logic port_miso,
		
		output logic[15 : 0]data_in, 
		input logic[15 : 0] data_out,
		
		input logic conf_cpol,
		input logic conf_dir, 
		input logic conf_cpha, 
		
		input logic[4 : 0] port_prescaler, 
		input logic[3 : 0] port_bit_count,
		
		
		output logic port_busy,
		output logic port_irq_flag, 
		input logic port_irq_clear_flag,
		input logic port_irq_enable
	);

	logic[1 : 0]port_cs_shift_reg = '0;
	logic[1 : 0]port_sck_shift_reg = '0;
	
	always_ff @ (posedge clock) port_cs_shift_reg <= {port_cs_shift_reg[0], port_cs};
	always_ff @ (posedge clock) port_sck_shift_reg <= {port_sck_shift_reg[0], port_sck};
	
	
	logic port_cs_rise, port_cs_fall, port_sck_rise, port_sck_fall;
	
	
	always_comb begin
		port_cs_rise = port_cs_shift_reg[0] & ~(port_cs_shift_reg[1]);
		port_cs_fall = port_cs_shift_reg[1] & ~(port_cs_shift_reg[0]);
		port_sck_rise = port_sck_shift_reg[0] & ~(port_sck_shift_reg[1]);
		port_sck_fall = port_sck_shift_reg[1] & ~(port_sck_shift_reg[0]);
	end
	
	logic sck_latch_edge, sck_setup_edge;
	
	
	
	assign sck_latch_edge = (conf_dir == `POL_RISING) ?  port_sck_rise : port_sck_fall;
	assign sck_setup_edge = (conf_dir == `POL_RISING) ? port_sck_fall : port_sck_rise;
	
	logic[15 : 0] data_in_buffer;
	logic mux_out;
	logic[3 : 0] sck_clock_count = '0;
	
	
	logic[3 : 0] mux_select;
	always_ff @ (posedge clock)
		if (conf_dir == `LSB_FIRST) begin
			mux_select = sck_clock_count;
		end else begin
			mux_select = port_bit_count - sck_clock_count;
		end
	mux_16to1 mux_miso
		(
			.in(data_out),
			.select(mux_select),
			.out(mux_out)
		);
	
	logic __cpha = '0;
	
	assign port_busy = port_cs ? '0 : '1;
	
	
	always_ff @ (posedge clock) begin
		if (port_irq_clear_flag)  begin
			port_irq_flag <= `LO;
		end else
			case (1'b1) 
				(port_cs_fall) : begin
						__cpha <= conf_cpha;
						data_in_buffer <= '0;
						port_miso = 'z;
				end
				(port_cs_rise) : begin
						data_in <= data_in_buffer;
						sck_clock_count <= `NULL;
						if (port_irq_enable)
							port_irq_flag <= `HI;
						
				end
				(sck_latch_edge & ~port_cs) : begin
						if (__cpha) __cpha <= __cpha - 1'b1;
						else begin
							data_in_buffer <= {data_in_buffer[14 : 0], port_mosi};
						end
						sck_clock_count <= sck_clock_count + 1'b1;
				end
				(sck_setup_edge & ~port_cs) : begin
						port_miso <= mux_out;	
				end
				default : begin
					
				end
			endcase	
		
	end
	//always_ff @ (posedge port_sck) 
	
endmodule

`endif /*__SPI*/