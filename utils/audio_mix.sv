
interface a_mix_wif_t;
    wire clk_i;
    logic rst_i;
    logic stb_i;
    logic stb_o;
    logic we_i;

    logic[7:0] addr_i;
    logic[31:0] dat_i;
    logic[31:0] dat_o;

    logic cyc_o;
endinterface

typedef struct {
    logic[31:0] addr;
    logic[31:0] len;
    logic[7:0] volume;
} a_chan_t;

typedef struct {
    logic[31:0] addr;
    logic[31:0] len;
} a_master_t;

module audio_mixer_8_16bps
(
    mem_wif_t.dev mem,

    a_mix_wif_t wif
);

assign mem.rst_i = wif.rst_i;

a_chan_t a_chan_pool[8];
a_master_t master;

logic[31:0] status = '0;

wire cmd_channel_x = wif.addr_i[7];
wire[2:0] cmd_channel_idx = wif.addr_i[6:4];
wire[3:0] cmd_channel_parm = wif.addr_i[3:0];

logic[3:0] chan_proc_idx = '0;
logic[7:0] volume = '0;
logic[31:0] mem_addr = '0;
logic signed[31:0] sample = '0;
logic not_empty = '0;

enum logic[3:0] {
    state_idle,
    state_prepare,
    state_chan_pld,
    state_mem_read,
    state_mem_read_ack,
    state_mem_read_ack2,
    state_mem_write,
    state_mem_write_ack,
    state_mix_p1,
    state_mix_p2,
    state_done
} a_state = state_idle, a_state_next = state_idle;

always_comb begin
    a_state = a_state_next;
end

always_ff @(posedge wif.clk_i) begin
	wif.stb_o <= wif.stb_i;
end

always_ff @(posedge wif.clk_i, posedge wif.rst_i) begin
    if (wif.rst_i) begin

        mem.stb_i <= '0;
        mem.we_i <= '1;
        mem.sel_i <= '1;
        mem.addr_i <= '0;
        mem.dat_o <= '0;
        not_empty <= '0;

        wif.cyc_o <= '0;
        wif.stb_o <= '0;
        wif.dat_o <= '0;
        a_state_next <= state_idle;

    end else if (wif.stb_i) begin
        if (!wif.we_i) begin /* Write op */
            if (cmd_channel_x) begin
                case (cmd_channel_parm)
                    4'h0: begin
                        a_chan_pool[cmd_channel_idx].addr <= wif.dat_i;
                    end
                    4'h1: begin
                        a_chan_pool[cmd_channel_idx].len <= wif.dat_i;
                    end
                    4'h2: begin
                        a_chan_pool[cmd_channel_idx].volume <= wif.dat_i[7:0];
                    end
                endcase
            end else begin
                case (wif.addr_i)
                    8'h0: begin
                        master.addr <= wif.dat_i;
                    end
                    8'h1: begin
                        master.len <= wif.dat_i;
                    end
                    8'h40: begin
                        if (wif.dat_i[0])
                            a_state_next <= state_prepare;
                    end
                endcase
            end
        end else begin /* Read op*/
            if (cmd_channel_x) begin
                case (cmd_channel_parm)
                    4'h0: begin
                        wif.dat_o <= a_chan_pool[cmd_channel_idx].addr;
                    end
                    4'h1: begin
                        wif.dat_o <= a_chan_pool[cmd_channel_idx].len;
                    end
                    4'h2: begin
                        wif.dat_o <= a_chan_pool[cmd_channel_idx].volume;
                    end
                endcase
            end else begin
                case (wif.addr_i)
                    8'h0: begin
                        wif.dat_o <= master.addr;
                    end
                    8'h1: begin
                        wif.dat_o <= master.len;
                    end
                    8'ha: begin
                        wif.dat_o <= status;
                    end
                endcase
            end
        end
    end else begin
        case (a_state)
            state_prepare: begin
                wif.cyc_o <= '1;
                chan_proc_idx <= '0;
                a_state_next <= state_chan_pld;
            end
            state_chan_pld: begin
                if (!master.len) begin
                    a_state_next <= state_done;

                end else if (chan_proc_idx == 4'h8) begin
                    chan_proc_idx <= '0;
                    not_empty <= '1;
                    if (!not_empty)
                        a_state_next <= state_done;
                    else
                        a_state_next <= state_mem_write;

                end else begin
                    chan_proc_idx <= chan_proc_idx + 1'b1;
                    if (a_chan_pool[chan_proc_idx].len) begin
                        mem_addr <= a_chan_pool[chan_proc_idx].addr;
                        volume <= a_chan_pool[chan_proc_idx].volume;

                        a_chan_pool[chan_proc_idx].addr <= a_chan_pool[chan_proc_idx].addr + 1'b1;
                        a_chan_pool[chan_proc_idx].len <= a_chan_pool[chan_proc_idx].len - 1'b1;

                        not_empty <= not_empty | '1;
                        a_state_next <= state_mem_read;
                    end
                end
            end
            state_mem_read: begin
                if (!mem.cyc_o) begin
                    if (mem.ack_o) begin
                        mem.stb_i <= '1;
                        mem.sel_i <= '1;
                        mem.addr_i <= mem_addr;
                        a_state_next <= state_mem_read_ack;
                    end else begin
                        mem.sel_i <= '0;
                    end
                end
            end
            state_mem_read_ack: begin
                if (mem.stb_o) begin
                    mem.stb_i <= '0;
                    a_state_next <= state_mem_read_ack2;
                end
            end
            state_mem_read_ack2: begin
                if (!mem.cyc_o) begin
                    sample <= mem.dat_i << 16;
                    mem.addr_i <= 0;
                    a_state_next <= state_mix_p1;
                end
            end
            state_mix_p1: begin
                sample <= sample * volume;
                a_state_next <= state_mix_p2;
            end
            state_mix_p2: begin
                sample <= {sample[31], sample[30:0] >> 3};
                if (chan_proc_idx == 4'h8) begin
                    a_state_next <= state_mem_write;
                end else begin
                    a_state_next <= state_chan_pld;
                end
            end
            state_mem_write: begin
                if (!mem.cyc_o) begin
                    if (mem.ack_o) begin
                        mem.sel_i <= '1;
                        mem.we_i <= '0;
                        mem.stb_i <= '1;
                        mem.addr_i <= master.addr;
                        mem.dat_o <= sample[31:16];
                        master.addr <= master.addr + 1'b1;
                        master.len <= master.len - 1'b1;
                        a_state_next <= state_mem_write_ack;
                    end else begin
                        mem.sel_i <= '0;
                    end
                end
            end
            state_mem_write_ack: begin
                mem.stb_i <= '0;
                if (!mem.cyc_o) begin
                    mem.sel_i <= '1;
                    mem.we_i <= '1;
                    mem.addr_i <= '0;
                    mem.dat_o <= '0;
                    a_state_next <= state_chan_pld;
                end
            end
            state_done: begin
                chan_proc_idx <= '0;
                wif.cyc_o <= '0;
                not_empty <= '0;
                a_state_next <= state_idle;
            end
        endcase
    end
end

endmodule