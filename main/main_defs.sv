`define 			MUTED					


`define			WRITE_PSRAM_LAT	16'h0070

`define			WRITE_DREGA			16'h0002
`define			WRITE_DREGB			16'h0003
`define			WRITE_DREGC			16'h0004

`define			READ_DREGA			16'h0002
`define			READ_DREGB			16'h0003
`define			READ_DREGC			16'h0004

`define			READ_STATUS			16'h0000
`define			READ_ID				16'h0001

`define			WRITE_FR_CTL		16'h0010

`define			READ_FR_STAT		16'h0010

`define			WRITE_UCPU_CTL		16'h0011
`define			WRITE_UCPU_IRQS	16'h0012



`define			READ_UCPU_STAT		16'h0011


`define			WRITE_GPU_COLOR	16'h0030
`define			WRITE_GPU_DEST_X	16'h0031
`define			WRITE_GPU_DEST_Y	16'h0032
`define			WRITE_GPU_DEST_W	16'h0033
`define			WRITE_GPU_DEST_H	16'h0034
`define			WRITE_GPU_DEST_LEG	16'h0035
`define			WRITE_GPU_SRC_X	16'h0036
`define			WRITE_GPU_SRC_Y	16'h0037
`define			WRITE_GPU_SRC_W	16'h0038
`define			WRITE_GPU_SRC_H	16'h0039
`define			WRITE_GPU_SRC_LEG	16'h003a
`define			WRITE_GPU_SCALE	16'h003b
`define			WRITE_GPU_DPL		16'h003c
`define			WRITE_GPU_DPH		16'h003d
`define			WRITE_GPU_SPL		16'h003e
`define			WRITE_GPU_SPH		16'h003f
`define			WRITE_GPU_SCALEX	16'h0040
`define			WRITE_GPU_SCALEY	16'h0041


`define			WRITE_FILL_CTL		16'h0050

`define			READ_FILL_STAT		16'h0050

`define			WRITE_COPY_CTL		16'h0060		

`define			READ_COPY_STAT		16'h0060


`define			WRITE_CS_CTL		16'h0080

`define			READ_BUSY			16'h0020
`define			READ_IRQS			16'h0021

`define			WRITE_IRQS_CLR		16'h0021


`define			READ_AMP_CY			16'h0100

`define			WRITE_TOUCH_CTL	16'h0110
`define			READ_TOUCH_STATE	16'h0110