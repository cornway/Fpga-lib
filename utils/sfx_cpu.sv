

module fxcpu16
(
    mem_wif_t.dev mem,

    input logic rst_i,

    output logic[1:0] addr_space,

    output wire[31:0] dbg_reg,

    input logic dbg_step
);

assign mem.rst_i = rst_i;

`include "sfxcpu_reg.sv"

logic halt = '0;

logic[15:0] pc = '0;

localparam RG_PC = 11;
localparam RG_SP = 10;

logic[31:0] rg[12];
wire[15:0] mstr;

logic alu_carry = '0;
logic alu_zero = '0;
logic alu_ovf = '0;
logic alu_neg = '0;
assign mstr[0] = {alu_carry, alu_zero, alu_ovf, alu_neg};

wire[4:0] alu_imm_short = pc[15:11];
logic signed[4:0] alu_imm_short_reg = '0; 

wire[7:0] opcode = pc[7:0];
wire signed[7:0] jnz_addr = pc[15:8];

wire reset = rst_i;
/*dst = src + src2*/
wire[1:0] rg_alu_dst_idx = pc[9:8];
wire[2:0] rg_alu_src_idx = pc[12:10];
wire[2:0] rg_alu_src2_idx = pc[15:13];

logic[1:0] rg_alu_dst_idx_reg = '0;
logic[2:0] rg_alu_src_idx_reg = '0;
logic[2:0] rg_alu_src2_idx_reg = '0;

wire[3:0] rg_mem_dst_idx = pc[11:8];
wire[3:0] rg_mem_src_idx = pc[15:12];

logic[3:0] rg_mem_dst_idx_reg = '0;
logic[3:0] rg_mem_src_idx_reg = '0;

logic mem_rd_req, mem_wr_req;
logic mem_ack = '0;
logic mem_busy = '0;

logic[15:0] mem_data_o = '0, mem_data_i = '0;
logic[31:0] mem_addr = '0;

logic alu_req = '0;
logic alu_req_ack = '0;
logic[64:0] alu_acc = '0;
wire signed[31:0] alu_acc32u = alu_acc[31:0];
wire signed[31:0] alu_acc32s = alu_acc[31:0];

assign addr_space = mem_addr[31:30];

logic[2:0] exec_mem_inc_after = '0;
logic first_fetch = '0;

enum logic[3:0] {
    state_alu_idle,
    state_alu_mul,
    state_alu_adds,
    state_alu_addi,
    state_alu_addi32,
    state_alu_divu,
    state_alu_and,
    state_alu_xor,
    state_alu_done
} alu_state = state_alu_idle, alu_req_state = state_alu_idle;

enum logic[3:0] {
    state_exec_idle,
    state_exec_ldmir,
    state_exec_ldmir_ack,
    state_exec_store_reg_lo,
    state_exec_store_reg_hi,
    state_exec_movi,
    state_exec_ji,
    state_exec_fetch_reg_lo,
    state_exec_fetch_reg_hi
} exec_state = state_exec_idle;

always_ff @(posedge mem.clk_i, posedge reset) begin
    if (reset) begin
        rg[RG_PC] <= '0;
        mem_addr <= '0;
        pc <= '0;
        halt <= '0;
        mem_wr_req <= '0;
        mem_rd_req <= '0;
        exec_mem_inc_after <= '0;
        first_fetch <= '1;
    end else if (first_fetch) begin
        rg[RG_PC] <= 32'h40000000;
        mem_addr <= 32'h40000000;
        mem_rd_req <= '1;
        exec_mem_inc_after <= '0;
        first_fetch <= '0;
    end else if (mem_rd_req || mem_wr_req) begin
        if (mem_ack) begin
            mem_rd_req <= '0;
            mem_wr_req <= '0;
            pc <= mem_data_i;
        end
    end else if (!halt && exec_state != state_exec_idle) begin
        case (exec_state)
            state_exec_ldmir: begin
                mem_addr <= rg[rg_mem_dst_idx_reg];
                mem_rd_req <= '1;
                exec_state <= state_exec_fetch_reg_hi;
                rg[rg_mem_dst_idx_reg] <= rg[rg_mem_dst_idx_reg] + exec_mem_inc_after;
                exec_mem_inc_after <= '0;
            end
            state_exec_store_reg_lo: begin
                mem_addr <= rg[RG_PC];
                mem_rd_req <= '1;
                exec_state <= state_exec_idle;
            end
            state_exec_store_reg_hi: begin
                mem_addr <= mem_addr - 2'h2;
                mem_data_o <= rg[rg_mem_src_idx_reg][15:0];
                mem_wr_req <= '1;
                exec_state <= state_exec_store_reg_lo;
            end
            state_exec_ji: begin
                mem_addr <= rg[rg_mem_dst_idx_reg];
                rg[RG_PC] <= rg[rg_mem_dst_idx_reg];
                mem_rd_req <= '1;
                exec_state <= state_exec_idle;
            end
            state_exec_fetch_reg_lo: begin
                rg[rg_mem_dst_idx_reg][15:0] <= mem_data_i;
                if (rg_mem_dst_idx_reg == RG_PC) begin
                    /*Case 'MOVW PC 0xxxx..'*/
                    mem_addr <= {rg[RG_PC][31:16], mem_data_i};
                end else begin
                    mem_addr <= rg[RG_PC];
                end
                mem_rd_req <= '1;
                exec_state <= state_exec_idle;
            end
            state_exec_fetch_reg_hi: begin
                rg[rg_mem_dst_idx_reg][31:16] <= mem_data_i;
                mem_addr <= mem_addr - 2'h2;
                mem_rd_req <= '1;
                exec_state <= state_exec_fetch_reg_lo;
            end
            default: begin
            end
        endcase
    end else begin
        if (alu_req) begin
            if (alu_req_ack) begin
                if (alu_req_state >= state_alu_adds && alu_req_state <= state_alu_addi) begin
                    rg[rg_alu_dst_idx_reg] <= alu_acc[15:0];
                end else begin
                    rg[rg_alu_dst_idx_reg] <= alu_acc32u;
                end
                alu_req_state <= state_alu_idle;
                alu_req <= '0;
            end
        end else if (opcode & ALU_OP_BM) begin
            case (opcode)
                OP_ADDS: begin
                    alu_req_state <= state_alu_adds;
                end
                OP_ADDI: begin
                    alu_imm_short_reg <= alu_imm_short;
                    alu_req_state <= state_alu_addi;
                end
                OP_ADDI32: begin
                    alu_imm_short_reg <= alu_imm_short;
                    alu_req_state <= state_alu_addi32;
                end
                OP_MUL: begin
                    alu_req_state <= state_alu_mul;
                end
                OP_DIVU: begin
                    alu_req_state <= state_alu_divu;
                end
                OP_AND: begin
                    alu_req_state <= state_alu_and;
                end
                OP_XOR: begin
                    alu_req_state <= state_alu_xor;
                end
            endcase
            rg_alu_dst_idx_reg <= rg_alu_src_idx;
            rg_alu_src_idx_reg <= rg_alu_src2_idx;
            rg_alu_src2_idx_reg <= rg_alu_dst_idx;
            rg[RG_PC] <= rg[RG_PC] + 2'h2;
            mem_addr <= rg[RG_PC] + 2'h2;
            alu_req <= '1;
            mem_rd_req <= '1;
        end else if (opcode & WRAP_OP_BM) begin
            case (opcode)
                OP_STMDB: begin
                    pc <= {rg_mem_src_idx, rg_mem_dst_idx, OP_STMI};
                    /* Decrement before */
                    rg[RG_SP] <= rg[RG_SP] - 3'h4;
                end
                OP_LDMIA: begin
                    pc <= {rg_mem_src_idx, rg_mem_dst_idx, OP_LDMI};
                    exec_mem_inc_after <= 3'h4;
                end
                OP_PUSH: begin
                    pc <= {rg_mem_src_idx, RG_SP, OP_STMI};
                    /* Decrement before */
                    rg[RG_SP] <= rg[RG_SP] - 3'h4;
                end
                OP_POP: begin
                    pc <= {rg_mem_src_idx, RG_SP, OP_LDMI};
                    exec_mem_inc_after <= 3'h4;
                end
            endcase
        end else if (opcode & MEM_OP_BM) begin
            case (opcode)
                OP_LDMI: begin
                    mem_addr <= rg[rg_mem_dst_idx] + 2'h2;
                    mem_rd_req <= '1;
                    exec_state <= state_exec_fetch_reg_hi;
                end
                OP_STMI: begin
                    mem_wr_req <= '1;
                    mem_addr <= rg[rg_mem_dst_idx] + 2'h2;
                    mem_data_o <= rg[rg_mem_src_idx][31:16];
                    exec_state <= state_exec_store_reg_hi;
                end
                OP_STM16: begin
                    mem_wr_req <= '1;
                    mem_addr <= rg[rg_mem_dst_idx];
                    mem_data_o <= rg[rg_mem_src_idx][15:0];
                    exec_state <= state_exec_store_reg_lo;
                end
                OP_LDM16: begin
                    mem_addr <= rg[rg_mem_dst_idx];
                    mem_rd_req <= '1;
                    exec_state <= state_exec_fetch_reg_lo;
                end
            endcase
            rg[RG_PC] <= rg[RG_PC] + 2'h2;
            rg_mem_dst_idx_reg <= rg_mem_dst_idx;
            rg_mem_src_idx_reg <= rg_mem_src_idx;
        end else case (opcode)
            OP_NOP: begin
                rg[RG_PC] <= rg[RG_PC] + 2'h2;
                mem_addr <= rg[RG_PC] + 2'h2;
                mem_rd_req <= '1;
            end
            OP_MOV: begin
                rg_mem_dst_idx_reg <= rg_mem_dst_idx;
                rg_mem_src_idx_reg <= rg_mem_src_idx;
                rg[RG_PC] <= rg[RG_PC] + 3'h4;
                mem_addr <= rg[RG_PC] + 2'h2;
                mem_rd_req <= '1;
                exec_state <= state_exec_fetch_reg_lo;
            end
            OP_MOVW: begin
                rg_mem_dst_idx_reg <= rg_mem_dst_idx;
                rg_mem_src_idx_reg <= rg_mem_src_idx;
                rg[RG_PC] <= rg[RG_PC] + 3'h6;
                mem_addr <= rg[RG_PC] + 2'h4;
                mem_rd_req <= '1;
                exec_state <= state_exec_fetch_reg_hi;
            end
            OP_JNZ: begin
                rg[RG_PC] <= $unsigned($signed(rg[RG_PC]) + jnz_addr);
                mem_addr <= $unsigned($signed(rg[RG_PC]) + jnz_addr);
                mem_rd_req <= '1;
            end
            OP_JI: begin
                /*TODO: Wrap that on the high layers*/
                pc <= {4'h0, RG_PC, OP_MOVW};
            end
            OP_JEQ: begin
                if (alu_zero) begin
                    pc <= {4'h0, RG_PC, OP_MOVW};
                end else begin
                    pc <= {8'h0, OP_NOP};
                end
            end
            default: begin
                halt <= '1;
            end
        endcase
    end
end

always_ff @(posedge mem.clk_i, posedge reset) begin
    if (reset) begin
        alu_state <= state_alu_idle;
        alu_req_ack <= '1;
    end else begin
        case (alu_state)
            state_alu_idle: begin
                if (alu_req) begin
                    alu_acc <= '0;
                    alu_state <= alu_req_state;
                end
            end
            state_alu_adds: begin
                alu_acc <= rg[rg_alu_src_idx_reg] + rg[rg_alu_src2_idx_reg];
                alu_state <= state_alu_done;
            end
            state_alu_addi : begin
                alu_acc <= $unsigned($signed(rg[rg_alu_src_idx_reg][15:0]) + alu_imm_short_reg);
                alu_state <= state_alu_done;
            end
            state_alu_addi32 : begin
                alu_acc <= $unsigned($signed(rg[rg_alu_src_idx_reg]) + alu_imm_short_reg);
                alu_state <= state_alu_done;
            end
            state_alu_mul: begin
                alu_acc <= rg[rg_alu_src_idx_reg][15:0] * rg[rg_alu_src2_idx_reg][15:0];
                alu_state <= state_alu_done;
            end
            state_alu_divu: begin
                alu_acc <= rg[rg_alu_src_idx_reg][15:0] / rg[rg_alu_src2_idx_reg][15:0];
                alu_state <= state_alu_done;
            end
            state_alu_and: begin
                alu_acc <= rg[rg_alu_src_idx_reg] & rg[rg_alu_src2_idx_reg];
                alu_state <= state_alu_done;
            end
            state_alu_xor: begin
                alu_acc <= rg[rg_alu_src_idx_reg] ^ rg[rg_alu_src2_idx_reg];
                alu_state <= state_alu_done;
            end
            state_alu_done: begin
                alu_carry <= alu_acc[32];
                alu_zero <= alu_acc == '0;
                alu_ovf <= |alu_acc[63:32];
                alu_neg <= alu_acc[31] | alu_acc[63];

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

always_ff @(posedge mem.clk_i, posedge reset) begin
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
