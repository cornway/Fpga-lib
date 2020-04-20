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

/*

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
				
			end else
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

*/







/*===================================================================================================================*/

`timescale 1ns/1ns

interface spi_phy_if;
    bit sck;
    bit mosi;
    bit miso;
    bit cs;
endinterface

interface spi_host_if;
    bit reset;
    bit clk_i;
    bit[15:0] dat_i;
    logic[15:0] dat_o;
    bit wr_req;
    bit wr_req_ack;
    bit busy;
endinterface

module spi_16bit_slave
    (
        spi_phy_if phy,
        spi_host_if spi_host,

        input logic conf_cpol,
        input logic conf_dir,
        input logic conf_cpha
    );

    logic[1 : 0]port_cs_shift_reg = '0;
    logic[1 : 0]port_sck_shift_reg = '0;

    always_ff @ (posedge spi_host.clk_i) port_cs_shift_reg <= {port_cs_shift_reg[0], phy.cs};
    always_ff @ (posedge spi_host.clk_i) port_sck_shift_reg <= {port_sck_shift_reg[0], phy.sck};

    logic port_cs_rise, port_cs_fall, port_sck_rise, port_sck_fall;

    always_comb begin
        port_cs_rise = port_cs_shift_reg[0] & ~(port_cs_shift_reg[1]);
        port_cs_fall = port_cs_shift_reg[1] & ~(port_cs_shift_reg[0]);
        port_sck_rise = port_sck_shift_reg[0] & ~(port_sck_shift_reg[1]);
        port_sck_fall = port_sck_shift_reg[1] & ~(port_sck_shift_reg[0]);
    end

    logic sck_latch_edge, sck_setup_edge;

    assign sck_latch_edge = port_sck_rise;
    assign sck_setup_edge = port_sck_fall;

    logic[15 : 0] data_in_buffer;
    logic[14:0] data_reg;

    assign spi_host.busy = phy.cs ? '0 : '1;

    always_ff @ (posedge sck_latch_edge, posedge port_cs_fall, posedge spi_host.wr_req_ack) begin
        if (port_cs_fall || spi_host.wr_req_ack) begin
            data_in_buffer <= '0;
        end else begin
            data_in_buffer <= {data_in_buffer[14 : 0], phy.mosi};
        end
    end

    always_ff @ (posedge spi_host.clk_i) begin
        if (spi_host.wr_req_ack || spi_host.reset) begin
            spi_host.wr_req <= '0;
        end else begin
                if (port_cs_fall) begin
                    {data_reg, phy.miso} <= spi_host.dat_o;
                end else if (port_cs_rise) begin
                    spi_host.dat_i <= data_in_buffer;
                    spi_host.wr_req <= '1;
                end else if (sck_setup_edge) begin
                    {data_reg[13:0], phy.miso} <= data_reg;
                end
        end
    end
endmodule

module spi_host_2_wif
(
    spi_host_if spi,
    mem_wif_t.dev mem,

    input logic[15:0] spi_rd_cmd
);

enum logic[2:0] {
    state_idle,
    state_write,
    state_write_ack,
    state_read,
    state_read_ack,
	 state_read_ack2
} spi_state = state_idle;

logic[15:0] spi_io_addr = '0;
logic spi_rd_req = '0;

always_ff @ (posedge mem.clk_i) begin
    if (mem.rst_i) begin
        mem.addr_i <= '0;
        mem.dat_o <= '0;
        mem.stb_i <= '0;
        mem.sel_i <= '1;
        mem.we_i <= '1;
        spi_state <= state_idle;
    end else begin
        case (spi_state)
            state_idle: begin
                if (spi.wr_req) begin
                    if (spi.dat_i == spi_rd_cmd) begin
                        spi_io_addr <= spi.dat_i;
                        spi_rd_req <= '1;
                    end else begin
                        spi_state <= state_write;
                    end
                end else if (spi_rd_req) begin
                    spi_rd_req <= '0;
                    spi_state <= state_read;
                end
            end
            state_write: begin
                if (!mem.cyc_o) begin
                    if (mem.ack_o) begin
                        mem.sel_i <= '1;
                        mem.we_i <= '0;
                        mem.stb_i <= '1;
                        mem.addr_i <= '0;
                        mem.dat_o <= spi.dat_i;
                        spi_state <= state_write_ack;
                    end else begin
                        mem.sel_i <= '0;
                    end
                end
            end
            state_write_ack: begin
                if (mem.stb_o) begin
                    mem.we_i <= '1;
                    mem.stb_i <= '0;
                    mem.addr_i <= '0;
                    mem.dat_o <= '0;
                    spi_state <= state_idle;
                end
            end
            state_read: begin
                if (!mem.cyc_o) begin
                    if (mem.ack_o) begin
                        mem.sel_i <= '1;
                        mem.addr_i <= spi_io_addr;
                        mem.stb_i <= '1;
                        spi_state <= state_read;
                    end else begin
                        mem.sel_i <= '0;
                    end
                end
            end
            state_read_ack: begin
                if (mem.stb_o) begin
                    mem.stb_i <= '0;
                    spi_state <= state_read_ack2;
                end
            end
            state_read_ack2: begin
                if (!mem.cyc_o) begin
                    spi.dat_o <= mem.dat_i;
                    mem.addr_i <= '0;
                    spi_state <= state_idle;
                end
            end
        endcase
        spi.wr_req_ack <= spi.wr_req;
    end
end

endmodule
