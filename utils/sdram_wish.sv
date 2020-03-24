
interface sdram_phy_if_t;
	wire[15:0] Dq;
	logic[11:0] Addr;
	logic[1:0] Ba;
	logic Clk;
	logic Cke;
	logic Cs_n;
	logic Ras_n;
	logic Cas_n;
	logic We_n;
	logic[1:0] Dqm;
endinterface

interface sdram_iface_host_t;
	logic[31:0] wr_addr;
    logic[15:0] wr_data;
    logic wr_enable;

    logic[31:0] rd_addr;
    logic[15:0] rd_data;
    logic rd_ready;
    logic rd_enable;

    logic busy;
    logic rst_n;
    wire clk;
endinterface

interface mem_wif_t;
    wire clk_i;
    logic rst_i;
    logic stb_i;
    logic stb_o;
    logic we_i;
    logic sel_i;

    logic[31:0] addr_i;
    logic[15:0] dat_i;
    logic[15:0] dat_o;

    logic cyc_o;
endinterface

module sdram_wish_if
(
    mem_wif_t wif,

    sdram_phy_if_t phy
);

    sdram_iface_host_t host();

    sdram_controller sdram_uc
        (
            .wr_addr(host.wr_addr),
            .wr_data(host.wr_data),
            .wr_enable(host.wr_enable),
            .rd_addr(host.rd_addr),
            .rd_data(host.rd_data),
            .rd_ready(host.rd_ready),
            .rd_enable(host.rd_enable),

            .busy(host.busy),
            .rst_n(host.rst_n),
            .clk(host.clk),

            /* SDRAM SIDE */
            .addr(phy.Addr),
            .bank_addr(phy.Ba),
            .data(phy.Dq),
            .clock_enable(phy.Cke),
            .cs_n(phy.Cs_n),
            .ras_n(phy.Ras_n),
            .cas_n(phy.Cas_n),
            .we_n(phy.We_n),
            .data_mask_low(phy.Dqm[0]),
            .data_mask_high(phy.Dqm[1])
        );

    enum logic[2:0] {
        state_idle,
        state_read,
        state_write,
        state_wait_rd_ack,
        state_wait_wr_ack,
        state_done
    } mem_state = state_idle, mem_state_next = state_idle;

    logic[31:0] mem_addr_reg;

    assign host.rd_addr = mem_addr_reg;
    assign host.wr_addr = mem_addr_reg;
    assign host.rst_n = ~wif.rst_i;
    assign host.clk = wif.clk_i;
    assign phy.Clk = wif.clk_i;

    always_comb begin
        mem_state = mem_state_next;
    end

    always_ff @ (posedge wif.clk_i) begin
        if (wif.rst_i) begin
            mem_state_next <= state_idle;
            wif.cyc_o <= '0;
            host.rd_enable <= '0;
            host.wr_enable <= '0;
        end else begin

            case (mem_state)

                state_idle: begin
                    if (wif.stb_i && !host.busy) begin
                        wif.cyc_o <= '1;
                        wif.stb_o <= '1;
                        mem_addr_reg <= wif.addr_i;
                        if (!wif.we_i)
                            mem_state_next <= state_write;
                        else
                            mem_state_next <= state_read;
                    end
                end
                state_read: begin
                    wif.stb_o <= '0;
                    host.rd_enable <= '1;
                    mem_state_next <= state_wait_rd_ack;
                end
                state_write: begin
                    wif.stb_o <= '0;
                    host.wr_data <= wif.dat_i;
                    host.wr_enable <= '1;
                    mem_state_next <= state_wait_wr_ack;
                end
                state_wait_rd_ack: begin
                    host.rd_enable <= '0;
                    if (host.rd_ready) begin
                        mem_addr_reg <= '0;
                        wif.dat_o <= host.rd_data;
                        mem_state_next <= state_done;
                    end
                end
                state_wait_wr_ack: begin
                    host.wr_enable <= '0;
                    if (!host.busy)
                        mem_state_next <= state_done;
                end
                state_done: begin
                    wif.cyc_o <= '0;
                    mem_state_next <= state_idle;
                end
            endcase
        end
    end

endmodule
