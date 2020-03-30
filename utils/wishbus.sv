
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
    assign user_0.dat_i = mem.dat_o;
    assign user_0.cyc_o = mem.cyc_o;
    assign user_0.stb_o = mem.stb_o;

    assign user_1.clk_i = mem.clk_i;
    assign user_1.dat_i = mem.dat_o;
    assign user_1.cyc_o = mem.cyc_o;
    assign user_1.stb_o = mem.stb_o;

    assign user_2.clk_i = mem.clk_i;
    assign user_2.dat_i = mem.dat_o;
    assign user_2.cyc_o = mem.cyc_o;
    assign user_2.stb_o = mem.stb_o;

    assign user_3.clk_i = mem.clk_i;
    assign user_3.dat_i = mem.dat_o;
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

    assign mem.dat_i =  (user_en[0] ? user_0.dat_o : '0) |
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
