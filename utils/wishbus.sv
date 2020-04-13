
module wishbus_4
(
    mem_wif_t.dev mem,

    mem_wif_t.user user_0,
    mem_wif_t.user user_1,
    mem_wif_t.user user_2,
    mem_wif_t.user user_3,

    input logic[3:0] user_en
);

    assign user_0.clk_i = mem.clk_i;
    assign user_0.dat_i = mem.dat_i;
    assign user_0.cyc_o = mem.cyc_o;
    assign user_0.stb_o = mem.stb_o;

    assign user_1.clk_i = mem.clk_i;
    assign user_1.dat_i = mem.dat_i;
    assign user_1.cyc_o = mem.cyc_o;
    assign user_1.stb_o = mem.stb_o;

    assign user_2.clk_i = mem.clk_i;
    assign user_2.dat_i = mem.dat_i;
    assign user_2.cyc_o = mem.cyc_o;
    assign user_2.stb_o = mem.stb_o;

    assign user_3.clk_i = mem.clk_i;
    assign user_3.dat_i = mem.dat_i;
    assign user_3.cyc_o = mem.cyc_o;
    assign user_3.stb_o = mem.stb_o;

    assign mem.ack_o = '0;

    assign mem.rst_i =  (user_0.rst_i & user_en[0]) |
                        (user_1.rst_i & user_en[1]) |
                        (user_2.rst_i & user_en[2]) |
                        (user_3.rst_i & user_en[3]);

    assign mem.addr_i = (user_en[0] ? user_0.addr_i : '0) |
                        (user_en[1] ? user_1.addr_i : '0) |
                        (user_en[2] ? user_2.addr_i : '0) |
                        (user_en[3] ? user_3.addr_i : '0);

    assign mem.dat_o =  (user_en[0] ? user_0.dat_o : '0) |
                        (user_en[1] ? user_1.dat_o : '0) |
                        (user_en[2] ? user_2.dat_o : '0) |
                        (user_en[3] ? user_3.dat_o : '0);

    assign mem.we_i =   (user_0.we_i | !user_en[0]) &
                        (user_1.we_i | !user_en[1]) &
                        (user_2.we_i | !user_en[2]) &
                        (user_3.we_i | !user_en[3]);

    assign mem.stb_i =  (user_0.stb_i & user_en[0]) |
                        (user_1.stb_i & user_en[1]) |
                        (user_2.stb_i & user_en[2]) |
                        (user_3.stb_i & user_en[3]);

    
    wire sel_0 = (user_0.sel_i | !user_en[0]);
    wire sel_1 = (user_1.sel_i | !user_en[1]);
    wire sel_2 = (user_2.sel_i | !user_en[2]);
    wire sel_3 = (user_3.sel_i | !user_en[3]);

    assign mem.sel_i =  (sel_0) &
                        (sel_1) &
                        (sel_2) &
                        (sel_3);

    wire mem_op_request = !mem.sel_i && !mem.stb_i && !mem.stb_o && !mem.cyc_o;
    logic mem_grant_wait = '0;

    always_ff @ (posedge mem.clk_i) begin
        if (mem.rst_i || mem_grant_wait) begin
            user_0.ack_o <= '0;
            user_1.ack_o <= '0;
            user_2.ack_o <= '0;
            user_3.ack_o <= '0;
            mem_grant_wait <= '0;
        end else if (mem_op_request) begin
            if (!sel_0) begin
                user_0.ack_o <= '1;
            end else if (!sel_1) begin
                user_1.ack_o <= '1;
            end else if (!sel_2) begin
                user_2.ack_o <= '1;
            end else if (!sel_3) begin
                user_3.ack_o <= '1;
            end
            mem_grant_wait <= '1;
        end
    end

endmodule


module wishbus_1to2
(
    mem_wif_t.dev mem_1,
    mem_wif_t.dev mem_2,

    mem_wif_t.user user,

    input logic mem_en
);

    //assign mem_1.rst_i = user.rst_i;
    assign mem_1.we_i  = mem_en ? '1 : user.we_i;
    assign mem_1.stb_i = mem_en ? '0 : user.stb_i;
    assign mem_1.dat_o = mem_en ? '0 : user.dat_o;
    assign mem_1.addr_i = mem_en ? '0 : user.addr_i;
    assign mem_1.sel_i = mem_en ? '1 : user.sel_i;
    //assign mem_1.clk_i = user.clk_i;

    //assign mem_2.rst_i = user.rst_i;
    assign mem_2.we_i  = mem_en ? user.we_i : '1;
    assign mem_2.stb_i = mem_en ? user.stb_i : '0;
    assign mem_2.dat_o = mem_en ? user.dat_o : '0;
    assign mem_2.addr_i = mem_en ? user.addr_i : '0;
    assign mem_2.sel_i = mem_en ? user.sel_i : '1;
    //assign mem_2.clk_i = user.clk_i;

    assign user.dat_i = mem_en ? mem_2.dat_i : mem_1.dat_i;
    assign user.cyc_o = mem_en ? mem_2.cyc_o : mem_1.cyc_o;
    assign user.stb_o = mem_en ? mem_2.stb_o : mem_1.stb_o;
    //assign user.ack_o = mem_en ? mem_2.ack_o : mem_1.ack_o;

endmodule

interface ram_phy_t ();
    logic[15:0] data;
    logic [9:0] rdaddress;
    logic rdclock;
    logic[9:0] wraddress;
    logic wrclock;
    logic wren;
    logic[15:0] q;
endinterface

module ram_2_wishbus
(
    ram_phy_t phy,

    mem_wif_t.user mem
);

enum logic[1:0] {
    state_idle,
    state_read,
    state_write,
    state_ack
} ram_state = state_idle;

assign mem.ack_o = '1;

always_ff @ (posedge mem.clk_i) begin
    if (mem.rst_i) begin
        ram_state <= state_idle;
        mem.stb_o <= '0;
        mem.cyc_o <= '0;
    end else begin
        case (ram_state)
            state_idle: begin
                if (mem.stb_i) begin
                    mem.stb_o <= '1;
                    mem.cyc_o <= '1;

                    phy.rdaddress <= {1'b0, mem.addr_i[31:1]};
                    phy.wraddress <= {1'b0, mem.addr_i[31:1]};

                    if (mem.we_i) begin
                        ram_state <= state_read;
                    end else begin
                        phy.data <= mem.dat_o;
                        phy.wren <= '1;
                        ram_state <= state_write;
                    end
                end
            end
            state_read: begin
                if (!mem.stb_i) begin
                    mem.stb_o <= '0;
                    phy.rdclock <= '1;
                    ram_state <= state_ack;
                end
            end
            state_write: begin
                if (!mem.stb_i) begin
                    mem.stb_o <= '0;
                    phy.wrclock <= '1;
                    ram_state <= state_ack;
                end
            end
            state_ack: begin
                if (!phy.wren) begin
                    mem.dat_i <= phy.q;
                end
                phy.wrclock <= '0;
                phy.rdclock <= '0;
                phy.wren <= '0;
                phy.data <= '0;
                phy.wraddress <= '0;
                phy.rdaddress <= '0;

                mem.cyc_o <= '0;

                ram_state <= state_idle;
            end
        endcase
    end
end

endmodule

module mem_burst_if
(
    input logic clk_i,
    input logic stb_i,
    input logic seq_i,
    input logic rst_i,
    input logic we_i,
    output logic cyc_o,
    output logic seq_o,
    input logic[15:0] len_i,
    input logic[15:0] dat_i,
    output logic[15:0] dat_o,
    input logic[31:0] addr_i,

    mem_wif_t.dev mem
);

enum logic[2:0] {
    state_idle,
    state_init,
    state_seq,
    state_req,
    state_ack,
    state_ack2,
    state_ack3,
    state_done
} mb_state = state_idle;

logic we_i_reg = '0;
logic[31:0] addr_reg = '0;
logic[15:0] data_reg = '0;
logic[15:0] data_len = '0;

assign mem.rst_i = rst_i;

always_ff @(posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
        mb_state <= state_idle;
        dat_o <= '0;
        data_reg <= '0;
        data_len <= '0;
        we_i_reg <= '0;
        addr_reg <= '0;
        seq_o <= '0;
        cyc_o <= '0;

        mem.stb_i <= '0;
        mem.we_i <= '1;
        mem.sel_i <= '1;
        mem.dat_o <= '0;
        mem.addr_i <= '0;

    end else begin
        case (mb_state)
            state_idle: begin
                if (stb_i) begin
                    data_len <= len_i;
                    addr_reg <= addr_i;
                    we_i_reg <= we_i;
                    cyc_o <= '1;
                    mb_state <= state_seq;
                end
            end
            state_seq: begin
                if (seq_i) begin
                    data_reg <= dat_i;
                    data_len <= data_len - 2'h2;
                    addr_reg <= addr_reg + 2'h2;
                    mb_state <= state_req;
                end
            end
            state_req: begin
                if (!mem.cyc_o) begin
                    if (mem.ack_o) begin
                        mem.sel_i <= '1;
                        mem.stb_i <= '1;
                        mem.we_i <= we_i_reg;
                        mem.addr_i <= addr_reg;
                        if (!we_i_reg) 
                            mem.dat_o <= data_reg;
                        mb_state <= state_ack;
                    end else begin
                        mem.sel_i <= '0;
                    end
                end
            end
            state_ack: begin
                if (mem.stb_o) begin
                    mem.stb_i <= '0;
                    mb_state <= state_ack2;
                end
            end
            state_ack2: begin
                if (!mem.cyc_o) begin
                    if (we_i_reg)
                        dat_o <= mem.dat_i;
                    seq_o <= '1;
                    mem.dat_o <= '0;
                    mem.addr_i <= '0;
                    mem.we_i <= '1;
                    if (data_len)
                        mb_state <= state_ack3;
                    else begin
                        mb_state <= state_done;
                    end
                end
            end
            state_ack3: begin
                if (!seq_i) begin
                    seq_o <= '0;
                    mb_state <= state_seq;
                end
            end
            state_done: begin
                if (!seq_i) begin
                    cyc_o <= '0;
                    seq_o <= '0;
                    mb_state <= state_idle;
                end
            end
        endcase
    end
end

endmodule