

module fxcpu16
(
    mem_wif_t.dev mem,

    input logic rst_i
);

assign mem.rst_i = '0;

localparam
    OP_NOP = 8'h0, // nop; {16'h0}; <nop> ...
    OP_LDMI = 8'h80, // load memory to reg; {dummy[15:11], dest[10:8], opcode[7:0]}; <ldmi> <addr lo> <addr hi>
    OP_STMI = 8'h81, // store reg to memory; {dummy[15:14], src[13:11], dummy[10:8], opcode[7:0]}; <stmi> <addr lo> <addr hi>
    OP_MOV = 8'h10, // mov immediate to reg; {dummy[15:11], dest[10:8], opcode[7:0]}; <mov> <imm 16 bit>
    OP_ADDS = 8'h40, // add two registers, write back; {dummy[15:14], src[13:11], dest[10:8], opcode[7:0]}; <adds>
    OP_MUL = 8'h41, // mul two registers, write back; {dummy[15:14], src[13:11], dest[10:8], opcode[7:0]}; <mul>
    OP_ADDI = 8'h42, // add reg with signed immediate; {imm[15:11], dest[10:8], opcode[7:0]}; <addi>
    OP_JNZ = 8'h20, // jump near zero, signed; {offset[15:8], opcode[7:0]}; <jnz> 
    OP_HALT = 8'hff; // halt everything until reset {dummy[15:8], opcode[7:0]}; <halt>

logic halt = '0;

logic[15:0] pc = '0;
logic[31:0] pc_addr = '0;

logic[15:0] rg[8];
wire[15:0] mstr;

logic[31:0] dbg_reg;

assign dbg_reg = {rg[1], rg[0]};

logic alu_carry = '0;
logic alu_zero = '0;
logic alu_ovf = '0;
assign mstr[0] = {alu_carry, alu_zero, alu_ovf};

wire[4:0] alu_imm_short = pc[15:11];
logic[4:0] alu_imm_short_reg = '0; 

wire[7:0] opcode = pc[7:0];
wire[7:0] jnz_addr = pc[15:8];

wire reset = rst_i;
wire[2:0] rg_num_dst = pc[10:8];
wire[2:0] rg_num_src = pc[13:11];

logic[2:0] rg_num_dst_reg = '0;
logic[2:0] rg_num_src_reg = '0;

logic mem_rd_req, mem_wr_req;
logic mem_ack = '0;
logic mem_busy = '0;

logic[15:0] mem_data_o = '0, mem_data_i = '0;
logic[31:0] mem_addr = '0;
logic[15:0] tmp_data = '0;
logic[31:0] tmp_addr = '0;

logic alu_req = '0;
logic alu_req_ack = '0;
logic[48:0] alu_acc = '0;

enum logic[3:0] {
    state_alu_idle,
    state_alu_mul,
    state_alu_adds,
    state_alu_addi,
    state_alu_done
} alu_state = state_alu_idle, alu_req_state = state_alu_idle;

enum logic[3:0] {
    state_exec_idle,
    state_exec_addr_lo,
    state_exec_addr_hi,
    state_exec_ldmir,
    state_exec_ldmir_ack,
    state_exec_stmir,
    state_exec_stmir_ack,
    state_exec_movi,
    state_exec_fetch_2_reg
} exec_state = state_exec_idle, exec_state_next = state_exec_idle;

always_ff @(posedge mem.clk_i) begin
    if (reset) begin
        pc_addr <= '0;
        halt <= '0;
        mem_rd_req <= '0;
        mem_wr_req <= '0;
        mem_addr <= '0;
    end else if (mem_rd_req || mem_wr_req) begin
        if (mem_ack) begin
            mem_rd_req <= '0;
            mem_wr_req <= '0;
            pc <= mem_data_i;
        end
    end else if (!halt && exec_state != state_exec_idle) begin
        case (exec_state)
            state_exec_addr_lo: begin
                tmp_addr[15:0] <= mem_data_i;
                mem_addr <= mem_addr + 2'h2;
                mem_rd_req <= '1;
                exec_state <= state_exec_addr_hi;
            end
            state_exec_addr_hi: begin
                tmp_addr[31:16] <= mem_data_i;
                exec_state <= exec_state_next;
            end
            state_exec_ldmir: begin
                mem_addr <= tmp_addr;
                mem_rd_req <= '1;
                exec_state <= state_exec_fetch_2_reg;
            end
            state_exec_stmir: begin
                if (!mem_busy) begin
                    mem_wr_req <= '1;
                    mem_addr <= tmp_addr;
                    mem_data_o <= rg[rg_num_src_reg];
                    exec_state <= state_exec_stmir_ack;
                end
            end
            state_exec_stmir_ack: begin
                mem_addr <= pc_addr;
                mem_rd_req <= '1;
                exec_state <= state_exec_idle;
            end
            state_exec_fetch_2_reg: begin
                rg[rg_num_dst_reg] <= mem_data_i;
                mem_addr <= pc_addr;
                mem_rd_req <= '1;
                exec_state <= state_exec_idle;
            end
            default: begin
            end
        endcase
    end else begin
        if (alu_req) begin
            if (alu_req_ack) begin
                case(alu_req_state)
                    state_alu_adds: begin
                        rg[rg_num_dst_reg] <= alu_acc[15:0];
                    end
                    state_alu_addi: begin
                        rg[rg_num_dst_reg] <= alu_acc[15:0];
                    end
                    state_alu_mul: begin
                        {rg[rg_num_dst], rg[rg_num_dst + 1'b1]} <= alu_acc;
                    end
                endcase
                alu_req_state <= state_alu_idle;
                alu_req <= '0;
            end
        end else case (opcode)
            OP_NOP: begin
                pc_addr <= pc_addr + 2'h2;
                mem_addr <= pc_addr + 2'h2;
                mem_rd_req <= '1;
            end
            OP_LDMI: begin
                rg_num_dst_reg <= rg_num_dst;
                rg_num_src_reg <= rg_num_src;
                pc_addr <= pc_addr + 3'h6;
                mem_addr <= pc_addr + 2'h2;
                mem_rd_req <= '1;
                exec_state <= state_exec_addr_lo;
                exec_state_next <= state_exec_ldmir;
            end
            OP_STMI: begin
                rg_num_dst_reg <= rg_num_dst;
                rg_num_src_reg <= rg_num_src;
                pc_addr <= pc_addr + 3'h6;
                mem_addr <= pc_addr + 2'h2;
                mem_rd_req <= '1;
                exec_state <= state_exec_addr_lo;
                exec_state_next <= state_exec_stmir;
            end
            OP_MOV: begin
                rg_num_dst_reg <= rg_num_dst;
                rg_num_src_reg <= rg_num_src;
                pc_addr <= pc_addr + 3'h4;
                mem_addr <= pc_addr + 2'h2;
                mem_rd_req <= '1;
                exec_state <= state_exec_fetch_2_reg;
            end
            OP_JNZ: begin
                if (jnz_addr[7]) begin
                    pc_addr <= pc_addr + jnz_addr - 9'h100;
                    mem_addr <= pc_addr + jnz_addr - 9'h100;
                end else begin
                    pc_addr <= pc_addr + jnz_addr;
                    mem_addr <= pc_addr + jnz_addr;
                end
                mem_rd_req <= '1;
            end
            OP_ADDS: begin
                alu_req_state <= state_alu_adds;
                alu_req <= '1;
                pc_addr <= pc_addr + 2'h2;
                mem_addr <= pc_addr + 2'h2;
                mem_rd_req <= '1;
            end
            OP_ADDI: begin
                rg_num_dst_reg <= rg_num_dst;
                alu_imm_short_reg <= alu_imm_short;
                alu_req_state <= state_alu_addi;
                alu_req <= '1;
                pc_addr <= pc_addr + 2'h2;
                mem_addr <= pc_addr + 2'h2;
                mem_rd_req <= '1;
            end
            OP_MUL: begin
                alu_req_state <= state_alu_mul;
                alu_req <= '1;
                pc_addr <= pc_addr + 2'h2;
                mem_addr <= pc_addr + 2'h2;
                mem_rd_req <= '1;
            end
            default: begin
                halt <= '1;
            end
        endcase
    end
end

always_ff @(posedge mem.clk_i) begin
    if (reset) begin
        alu_state <= state_alu_idle;
        alu_req_ack <= '1;
    end else begin
        case (alu_state)
            state_alu_idle: begin
                if (alu_req) begin
                    alu_state <= alu_req_state;
                end
            end
            state_alu_adds: begin
                alu_acc <= rg[rg_num_dst_reg] + rg[rg_num_src_reg];
                alu_state <= state_alu_done;
            end
            state_alu_addi : begin
                if (alu_imm_short_reg[4]) begin
                    alu_acc <= rg[rg_num_dst_reg] + alu_imm_short_reg - 6'h3f;
                end else begin
                    alu_acc <= rg[rg_num_dst_reg] + alu_imm_short_reg;
                end
                alu_state <= state_alu_done;
            end
            state_alu_mul: begin
                alu_acc <= rg[rg_num_dst_reg] * rg[rg_num_src_reg];
                alu_state <= state_alu_done;
            end
            state_alu_done: begin
                alu_carry <= alu_acc[16];
                alu_zero <= alu_acc == '0;
                alu_ovf <= |alu_acc[47:16];

                if (!alu_req) begin
                    alu_req_ack <= '0;
                    alu_state <= state_alu_idle;
                end else begin
                    alu_req_ack <= '1;
                end
            end
        endcase
    end
end

enum logic[2:0] {
    state_mem_idle,
    state_mem_read,
    state_mem_rd_ack,
    state_mem_rd_ack2,
    state_mem_write,
    state_mem_wr_ack,
    state_mem_done
} mem_state = state_mem_idle;

always_ff @(posedge mem.clk_i) begin
    if (reset) begin
        mem_state <= state_mem_idle;
        mem.dat_o <= '0;
        mem.addr_i <= '0;
        mem.sel_i <= '1;
        mem.we_i <= '1;
        mem.stb_i <= '0;
        mem_ack <= '0;
    end else begin
        case (mem_state)
            state_mem_idle: begin
                mem_ack <= '0;
                if (mem_rd_req) begin
                    mem_state <= state_mem_read;
                    mem_busy <= '1;
                end else if (mem_wr_req) begin
                    mem_state <= state_mem_write;
                    mem_busy <= '1;
                end else begin
                    mem_busy <= '0;
                end
            end
            state_mem_write: begin
                if (!mem.cyc_o) begin
                    if (mem.ack_o) begin
                        mem.sel_i <= '1;
                        mem.addr_i <= mem_addr;
                        mem.dat_o <= mem_data_o;
                        mem.stb_i <= '1;
                        mem.we_i <= '0;
                        mem_state <= state_mem_wr_ack;
                    end else begin
                        mem.sel_i <= '0;
                    end
                end
            end
            state_mem_wr_ack: begin
                if (mem.stb_o) begin
                    mem.we_i <= '1;
                    mem.addr_i <= '0;
                    mem.dat_o <= '0;
                    mem_ack <= '1;
                    mem_state <= state_mem_idle;
                end
            end
            state_mem_read: begin
                if (!mem.cyc_o) begin
                    if (mem.ack_o) begin
                        mem.sel_i <= '1;
                        mem.addr_i <= mem_addr;
                        mem.stb_i <= '1;
                        mem_state <= state_mem_rd_ack;
                    end else begin
                        mem.sel_i <= '0;
                    end
                end
            end
            state_mem_rd_ack: begin
                if (mem.stb_o) begin
                    mem.stb_i <= '0;
                    mem_state <= state_mem_rd_ack2;
                end
            end
            state_mem_rd_ack2: begin
                if (!mem.cyc_o) begin
                    mem_data_i <= mem.dat_i;
                    mem.addr_i <= '0;
                    mem_ack <= '1;
                    mem_state <= state_mem_idle;
                end
            end
        endcase
    end
end

endmodule
