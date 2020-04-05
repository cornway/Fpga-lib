
module digital_tube_8x4_static
(
    input logic clk_1KHz,
    input logic rst_i,
    input logic[15:0] dig_i,

    output logic[7:0] seg_o,
    output logic[3:0] dig_o
);

function logic[7:0] _2nibble (input logic[3:0] n);
    case (n)
        4'h0 : _2nibble = 8'hc0; //"0"
        4'h1 : _2nibble = 8'hf9; //"1"
        4'h2 : _2nibble = 8'ha4; //"2"
        4'h3 : _2nibble = 8'hb0; //"3"
        4'h4 : _2nibble = 8'h99; //"4"
        4'h5 : _2nibble = 8'h92; //"5"
        4'h6 : _2nibble = 8'h82; //"6"
        4'h7 : _2nibble = 8'hf8; //"7"
        4'h8 : _2nibble = 8'h80; //"8"
        4'h9 : _2nibble = 8'h90; //"9"
        4'ha : _2nibble = 8'h88; //"a"
        4'hb : _2nibble = 8'h83; //"b"
        4'hc : _2nibble = 8'hc6; //"c"
        4'hd : _2nibble = 8'ha1; //"d"
        4'he : _2nibble = 8'h86; //"e"
        4'hf : _2nibble = 8'h8e; //"f"
    endcase
endfunction

    logic[7:0] data[4];
    logic[1:0] cnt = '0;

    assign data[0] = _2nibble(dig_i[3:0]);
    assign data[1] = _2nibble(dig_i[7:4]);
    assign data[2] = _2nibble(dig_i[11:8]);
    assign data[3] = _2nibble(dig_i[15:12]);

    always_comb begin
        seg_o = data[cnt];
        case (cnt)
            4'h0: dig_o = 4'b1110;
            4'h1: dig_o = 4'b1101;
            4'h2: dig_o = 4'b1011;
            4'h3: dig_o = 4'b0111;
        endcase
    end

    always_ff @(posedge clk_1KHz) begin
        cnt <= cnt + 1'b1;
    end

endmodule

