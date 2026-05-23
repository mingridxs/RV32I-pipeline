module Encoder_Radix_4 (
	yi,
	neg,
	mul_2x,
	mul_1x
);
	input wire [2:0] yi;
	output wire neg;
	output wire mul_2x;
	output wire mul_1x;
	assign neg = yi[2];
	assign mul_2x = ((yi[2] & ~yi[1]) & ~yi[0]) | ((~yi[2] & yi[1]) & yi[0]);
	assign mul_1x = yi[1] ^ yi[0];
endmodule
module Single_Bit_Decoder (
	yi,
	mul_1x,
	mul_2x,
	neg,
	partial
);
	input wire [1:0] yi;
	input wire mul_1x;
	input wire mul_2x;
	input wire neg;
	output reg partial;
	always @(*) begin
		if (mul_1x & ~mul_2x)
			partial = yi[1];
		else if (~mul_1x & mul_2x)
			partial = yi[0];
		else
			partial = 0;
		partial = neg ^ partial;
	end
endmodule
module Zerar (
	A,
	B
);
	input wire A;
	output wire B;
	assign B = A;
endmodule
module MSBDecider (
	y,
	mul_1x,
	mul_2x,
	neg,
	nosignal,
	partial
);
	input wire y;
	input wire mul_1x;
	input wire mul_2x;
	input wire neg;
	input wire nosignal;
	output reg partial;
	always @(*)
		if (nosignal && y)
			partial = ((~neg & ~mul_1x) & mul_2x) | (neg & ~mul_2x);
		else
			partial = neg ^ (y & (mul_1x | mul_2x));
endmodule
module EXTDecider (
	msb,
	y,
	nosignal,
	neg,
	extension
);
	input wire msb;
	input wire y;
	input wire nosignal;
	input wire neg;
	output reg extension;
	always @(*)
		if ((nosignal && y) && ~neg)
			extension = 0;
		else if ((nosignal && y) && neg)
			extension = 1;
		else
			extension = msb;
endmodule
module Decoder_64 (
	y,
	mul_1x,
	mul_2x,
	neg,
	nosignal,
	partial,
	partial_ext
);
	input wire [31:0] y;
	input wire mul_1x;
	input wire mul_2x;
	input wire neg;
	input wire nosignal;
	output reg [63:0] partial;
	output wire [63:0] partial_ext;
	wire [63:0] partial_int;
	wire temp = 0;
	wire [32:0] y33;
	assign y33 = {y, temp};
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 64; _gv_i_1 = _gv_i_1 + 1) begin : decoders
			localparam i = _gv_i_1;
			if (i < 32) begin : genblk1
				Single_Bit_Decoder sbd(
					.yi(y33[i + 1:i]),
					.mul_1x(mul_1x),
					.mul_2x(mul_2x),
					.neg(neg),
					.partial(partial_int[i])
				);
			end
			else if (i == 32) begin : genblk1
				MSBDecider most(
					.y(y[31]),
					.mul_1x(mul_1x),
					.mul_2x(mul_2x),
					.neg(neg),
					.nosignal(nosignal),
					.partial(partial_int[i])
				);
			end
			else begin : genblk1
				EXTDecider ext(
					.msb(partial_int[32]),
					.y(y[31]),
					.nosignal(nosignal),
					.neg(neg),
					.extension(partial_int[i])
				);
			end
		end
	endgenerate
	always @(*)
		if (neg)
			partial = partial_int + 1;
		else
			partial = partial_int;
	assign partial_ext = partial;
endmodule
module Compressor4_2 (
	A,
	B,
	C,
	D,
	Cin,
	Cout,
	Carry,
	S
);
	input wire A;
	input wire B;
	input wire C;
	input wire D;
	input wire Cin;
	output wire Cout;
	output wire Carry;
	output wire S;
	assign S = (((A ^ B) ^ C) ^ D) ^ Cin;
	assign Carry = ((((A ^ B) ^ C) ^ D) & Cin) | (~(((A ^ B) ^ C) ^ D) & D);
	assign Cout = ((A ^ B) & C) | (A & B);
endmodule
module Gambiarra (
	A,
	B,
	C,
	D
);
	input wire A;
	input wire B;
	output wire C;
	output wire D;
	assign C = A;
	assign D = B;
endmodule
module PP4Adder (
	A,
	B,
	C,
	D,
	P_low,
	P_high
);
	input wire [63:0] A;
	input wire [63:0] B;
	input wire [63:0] C;
	input wire [63:0] D;
	output wire [63:0] P_low;
	output reg [63:0] P_high;
	wire zero;
	assign zero = 0;
	wire [64:0] carries;
	wire [64:0] carryouts;
	assign carries[0] = 0;
	assign carryouts[0] = 0;
	wire [63:0] B_shifted;
	wire [63:0] C_shifted;
	wire [63:0] D_shifted;
	assign B_shifted = B;
	assign C_shifted = C;
	assign D_shifted = D;
	genvar _gv_i_2;
	generate
		for (_gv_i_2 = 0; _gv_i_2 < 64; _gv_i_2 = _gv_i_2 + 1) begin : sum
			localparam i = _gv_i_2;
			Compressor4_2 compressor(
				.A(B_shifted[i]),
				.B(C_shifted[i]),
				.C(D_shifted[i]),
				.D(carryouts[i]),
				.Cin(carries[i]),
				.Cout(carries[i + 1]),
				.Carry(carryouts[i + 1]),
				.S(P_low[i])
			);
			wire [1:1] sv2v_tmp_zera_B;
			always @(*) P_high[i] = sv2v_tmp_zera_B;
			Zerar zera(
				.A(A[i]),
				.B(sv2v_tmp_zera_B)
			);
		end
	endgenerate
endmodule
module PP2Adder (
	A,
	B,
	S
);
	input wire [63:0] A;
	input wire [63:0] B;
	output reg [63:0] S;
	always @(*) S = A + B;
endmodule
module MulSignalRegister (
	Clk,
	Reset,
	in_funct3,
	in_Rd,
	in_1x,
	in_2x,
	in_neg,
	in_op,
	out_funct3,
	mul_1x,
	mul_2x,
	neg,
	op,
	Rd
);
	input wire Clk;
	input wire Reset;
	input wire [1:0] in_funct3;
	input wire [4:0] in_Rd;
	input wire [15:0] in_1x;
	input wire [15:0] in_2x;
	input wire [15:0] in_neg;
	input wire [31:0] in_op;
	output reg [1:0] out_funct3;
	output reg [15:0] mul_1x;
	output reg [15:0] mul_2x;
	output reg [15:0] neg;
	output reg [31:0] op;
	output reg [4:0] Rd;
	always @(posedge Clk or posedge Reset)
		if (Reset == 1) begin
			mul_1x <= 16'b0000000000000000;
			mul_2x <= 16'b0000000000000000;
			neg <= 16'b0000000000000000;
			op <= 32'b00000000000000000000000000000000;
			Rd <= 5'b00000;
			out_funct3 <= 2'b00;
		end
		else begin
			mul_1x <= in_1x;
			mul_2x <= in_2x;
			neg <= in_neg;
			op <= in_op;
			Rd <= in_Rd;
			out_funct3 <= in_funct3;
		end
endmodule
module PPRegister (
	Clk,
	Reset,
	in_op,
	in_funct3,
	in_Rd,
	in_pp,
	out_funct3,
	pp,
	Rd,
	pp_op
);
	input wire Clk;
	input wire Reset;
	input wire [63:0] in_op;
	input wire [1:0] in_funct3;
	input wire [4:0] in_Rd;
	input wire [1023:0] in_pp;
	output reg [1:0] out_funct3;
	output reg [1023:0] pp;
	output reg [4:0] Rd;
	output reg [63:0] pp_op;
	integer i;
	always @(posedge Clk or posedge Reset)
		if (Reset) begin
			for (i = 0; i < 16; i = i + 1)
				pp[(15 - i) * 64+:64] <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			Rd <= 5'b00000;
			out_funct3 <= 2'b00;
			pp_op <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
		end
		else begin
			for (i = 0; i < 16; i = i + 1)
				pp[(15 - i) * 64+:64] <= in_pp[(15 - i) * 64+:64];
			Rd <= in_Rd;
			out_funct3 <= in_funct3;
			pp_op <= in_op;
		end
endmodule
module FirstBlockRegister (
	Clk,
	Reset,
	pp_op,
	in_funct3,
	in_Rd,
	in_first,
	out_funct3,
	first,
	Rd,
	first_op
);
	input wire Clk;
	input wire Reset;
	input wire [63:0] pp_op;
	input wire [1:0] in_funct3;
	input wire [4:0] in_Rd;
	input wire [511:0] in_first;
	output reg [1:0] out_funct3;
	output reg [511:0] first;
	output reg [4:0] Rd;
	output reg [63:0] first_op;
	integer i;
	always @(posedge Clk or posedge Reset)
		if (Reset == 1) begin
			Rd <= 5'b00000;
			out_funct3 <= 2'b00;
			first_op <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			for (i = 0; i < 8; i = i + 1)
				first[i * 64+:64] <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
		end
		else begin
			Rd <= in_Rd;
			out_funct3 <= in_funct3;
			first_op <= pp_op;
			for (i = 0; i < 8; i = i + 1)
				first[i * 64+:64] <= in_first[i * 64+:64];
		end
endmodule
module SecondBlockRegister (
	Clk,
	Reset,
	first_op,
	in_funct3,
	in_Rd,
	in_second,
	out_funct3,
	second,
	Rd,
	second_op
);
	input wire Clk;
	input wire Reset;
	input wire [63:0] first_op;
	input wire [1:0] in_funct3;
	input wire [4:0] in_Rd;
	input wire [255:0] in_second;
	output reg [1:0] out_funct3;
	output reg [255:0] second;
	output reg [4:0] Rd;
	output reg [63:0] second_op;
	integer i;
	always @(posedge Clk or posedge Reset)
		if (Reset == 1) begin
			Rd <= 5'b00000;
			out_funct3 <= 2'b00;
			second_op <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			for (i = 0; i < 4; i = i + 1)
				second[i * 64+:64] <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
		end
		else begin
			Rd <= in_Rd;
			out_funct3 <= in_funct3;
			second_op <= first_op;
			for (i = 0; i < 4; i = i + 1)
				second[i * 64+:64] <= in_second[i * 64+:64];
		end
endmodule
module ThirdBlockRegister (
	Clk,
	Reset,
	second_op,
	in_funct3,
	in_Rd,
	in_third,
	out_funct3,
	third,
	Rd,
	third_op
);
	input wire Clk;
	input wire Reset;
	input wire [63:0] second_op;
	input wire [1:0] in_funct3;
	input wire [4:0] in_Rd;
	input wire [127:0] in_third;
	output reg [1:0] out_funct3;
	output reg [127:0] third;
	output reg [4:0] Rd;
	output reg [63:0] third_op;
	integer i;
	always @(posedge Clk or posedge Reset)
		if (Reset == 1) begin
			Rd <= 5'b00000;
			out_funct3 <= 2'b00;
			third_op <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			for (i = 0; i < 2; i = i + 1)
				third[i * 64+:64] <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
		end
		else begin
			Rd <= in_Rd;
			out_funct3 <= in_funct3;
			third_op <= second_op;
			for (i = 0; i < 2; i = i + 1)
				third[i * 64+:64] <= in_third[i * 64+:64];
		end
endmodule
module ResultBlockRegister (
	Clk,
	Reset,
	third_op,
	in_funct3,
	in_Rd,
	in_res,
	out_funct3,
	res,
	Rd,
	almost_op
);
	input wire Clk;
	input wire Reset;
	input wire [63:0] third_op;
	input wire [1:0] in_funct3;
	input wire [4:0] in_Rd;
	input wire [63:0] in_res;
	output reg [1:0] out_funct3;
	output reg [63:0] res;
	output reg [4:0] Rd;
	output reg [63:0] almost_op;
	always @(posedge Clk or posedge Reset)
		if (Reset == 1) begin
			Rd <= 5'b00000;
			res <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			almost_op <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
			out_funct3 <= in_funct3;
		end
		else begin
			Rd <= in_Rd;
			res <= in_res;
			out_funct3 <= in_funct3;
			almost_op <= third_op;
		end
endmodule
module MulPipelined32Bits (
	Clk,
	Reset,
	mul,
	funct3,
	A,
	B,
	Rd,
	counter,
	regularS,
	unsignedS,
	tempS,
	tempU
);
	input wire Clk;
	input wire Reset;
	input wire mul;
	input wire [1:0] funct3;
	input wire [31:0] A;
	input wire [31:0] B;
	input wire [4:0] Rd;
	output reg [2:0] counter;
	output reg [31:0] regularS;
	output reg [31:0] unsignedS;
	output reg [63:0] tempS;
	output reg [63:0] tempU;
	always @(posedge Clk or posedge Reset)
		if (Reset)
			counter <= 3'b000;
		else if ((mul == 1'b0) || ((counter == 3'b110) && (funct3[1] == 1'b0)))
			counter <= 3'b000;
		else
			counter <= counter + 1;
	wire [15:0] mul_1x;
	wire [15:0] mul_2x;
	wire [15:0] neg;
	wire [15:0] mul_1x_pre;
	wire [15:0] mul_2x_pre;
	wire [15:0] neg_pre;
	wire [31:0] op;
	wire [4:0] signal_rd;
	wire [1:0] signal_funct3;
	wire temp;
	assign temp = 0;
	genvar _gv_i_3;
	generate
		for (_gv_i_3 = 0; _gv_i_3 < 16; _gv_i_3 = _gv_i_3 + 1) begin : signals
			localparam i = _gv_i_3;
			if (i == 0) begin : genblk1
				Encoder_Radix_4 encoder(
					.yi({B[1:0], temp}),
					.neg(neg_pre[i]),
					.mul_2x(mul_2x_pre[i]),
					.mul_1x(mul_1x_pre[i])
				);
			end
			else begin : genblk1
				Encoder_Radix_4 encoder(
					.yi(B[(2 * i) + 1:(2 * i) - 1]),
					.neg(neg_pre[i]),
					.mul_2x(mul_2x_pre[i]),
					.mul_1x(mul_1x_pre[i])
				);
			end
		end
	endgenerate
	MulSignalRegister signalreg(
		.Clk(Clk),
		.Reset(Reset),
		.in_funct3(funct3),
		.in_Rd(Rd),
		.in_1x(mul_1x_pre),
		.in_2x(mul_2x_pre),
		.in_neg(neg_pre),
		.in_op(A),
		.out_funct3(signal_funct3),
		.mul_1x(mul_1x),
		.mul_2x(mul_2x),
		.neg(neg),
		.op(op),
		.Rd(signal_rd)
	);
	wire [63:0] partialUnused [15:0];
	wire [63:0] partials [15:0];
	genvar _gv_j_1;
	generate
		for (_gv_j_1 = 0; _gv_j_1 < 16; _gv_j_1 = _gv_j_1 + 1) begin : pps
			localparam j = _gv_j_1;
			Decoder_64 decoder(
				.y(op),
				.mul_1x(mul_1x[j]),
				.mul_2x(mul_2x[j]),
				.neg(neg[j]),
				.nosignal(funct3[1] & funct3[0]),
				.partial(partialUnused[j]),
				.partial_ext(partials[j])
			);
		end
	endgenerate
	wire [1023:0] pp_shifted;
	wire [63:0] shifted_extra;
	assign pp_shifted[0+:64] = partials[0];
	assign pp_shifted[64+:64] = {partials[1][61:0], 2'b00};
	assign pp_shifted[128+:64] = {partials[2][59:0], 4'b0000};
	assign pp_shifted[192+:64] = {partials[3][57:0], 6'b000000};
	assign pp_shifted[256+:64] = {partials[4][55:0], 8'b00000000};
	assign pp_shifted[320+:64] = {partials[5][53:0], 10'b0000000000};
	assign pp_shifted[384+:64] = {partials[6][51:0], 12'b000000000000};
	assign pp_shifted[448+:64] = {partials[7][49:0], 14'b00000000000000};
	assign pp_shifted[512+:64] = {partials[8][47:0], 16'b0000000000000000};
	assign pp_shifted[576+:64] = {partials[9][45:0], 18'b000000000000000000};
	assign pp_shifted[640+:64] = {partials[10][43:0], 20'b00000000000000000000};
	assign pp_shifted[704+:64] = {partials[11][41:0], 22'b0000000000000000000000};
	assign pp_shifted[768+:64] = {partials[12][39:0], 24'b000000000000000000000000};
	assign pp_shifted[832+:64] = {partials[13][37:0], 26'b00000000000000000000000000};
	assign pp_shifted[896+:64] = {partials[14][35:0], 28'b0000000000000000000000000000};
	assign pp_shifted[960+:64] = {partials[15][33:0], 30'b000000000000000000000000000000};
	assign shifted_extra = {op, 32'b00000000000000000000000000000000};
	wire [1023:0] pp_def;
	wire [4:0] pp_rd;
	wire [1:0] pp_funct3;
	wire [63:0] pp_op;
	PPRegister ppreg(
		.Clk(Clk),
		.Reset(Reset),
		.in_op(shifted_extra),
		.in_funct3(signal_funct3),
		.in_Rd(signal_rd),
		.in_pp(pp_shifted),
		.out_funct3(pp_funct3),
		.pp(pp_def),
		.Rd(pp_rd),
		.pp_op(pp_op)
	);
	wire [4:0] first_rd;
	wire [1:0] first_funct3;
	wire [511:0] Firstpre;
	wire [511:0] First;
	wire [63:0] first_op;
	genvar _gv_k_1;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : first_level
			localparam k = _gv_k_1;
			PP4Adder firstAdder(
				.A(pp_def[(k * 4) * 64+:64]),
				.B(pp_def[((k * 4) + 1) * 64+:64]),
				.C(pp_def[((k * 4) + 2) * 64+:64]),
				.D(pp_def[((k * 4) + 3) * 64+:64]),
				.P_low(Firstpre[(k * 2) * 64+:64]),
				.P_high(Firstpre[((k * 2) + 1) * 64+:64])
			);
		end
	endgenerate
	FirstBlockRegister firstreg(
		.Clk(Clk),
		.Reset(Reset),
		.pp_op(pp_op),
		.in_funct3(pp_funct3),
		.in_Rd(pp_rd),
		.in_first(Firstpre),
		.out_funct3(first_funct3),
		.first(First),
		.Rd(first_rd),
		.first_op(first_op)
	);
	wire [4:0] second_rd;
	wire [1:0] second_funct3;
	wire [255:0] Secondpre;
	wire [255:0] Second;
	wire [63:0] second_op;
	genvar _gv_l_1;
	generate
		for (_gv_l_1 = 0; _gv_l_1 < 4; _gv_l_1 = _gv_l_1 + 1) begin : second_level
			localparam l = _gv_l_1;
			PP2Adder secondAdder(
				.A(First[(l * 2) * 64+:64]),
				.B(First[((l * 2) + 1) * 64+:64]),
				.S(Secondpre[l * 64+:64])
			);
		end
	endgenerate
	SecondBlockRegister secondreg(
		.Clk(Clk),
		.Reset(Reset),
		.first_op(first_op),
		.in_funct3(first_funct3),
		.in_Rd(first_rd),
		.in_second(Secondpre),
		.out_funct3(second_funct3),
		.second(Second),
		.Rd(second_rd),
		.second_op(second_op)
	);
	wire [4:0] third_rd;
	wire [1:0] third_funct3;
	wire [127:0] Thirdpre;
	wire [127:0] Third;
	wire [63:0] third_op;
	PP4Adder third_level(
		.A(Second[0+:64]),
		.B(Second[64+:64]),
		.C(Second[128+:64]),
		.D(Second[192+:64]),
		.P_low(Thirdpre[0+:64]),
		.P_high(Thirdpre[64+:64])
	);
	ThirdBlockRegister thirdreg(
		.Clk(Clk),
		.Reset(Reset),
		.second_op(second_op),
		.in_funct3(second_funct3),
		.in_Rd(second_rd),
		.in_third(Thirdpre),
		.out_funct3(third_funct3),
		.third(Third),
		.Rd(third_rd),
		.third_op(third_op)
	);
	wire [4:0] fourth_rd;
	wire [1:0] fourth_funct3;
	wire [63:0] preResult;
	PP2Adder fourth_level(
		.A(Third[0+:64]),
		.B(Third[64+:64]),
		.S(preResult)
	);
	wire [63:0] preS;
	wire [63:0] pre_op;
	ResultBlockRegister lastreg(
		.Clk(Clk),
		.Reset(Reset),
		.third_op(third_op),
		.in_funct3(third_funct3),
		.in_Rd(third_rd),
		.in_res(preResult),
		.out_funct3(fourth_funct3),
		.res(preS),
		.Rd(fourth_rd),
		.almost_op(pre_op)
	);
	always @(*)
		if (fourth_funct3 == 2'b01)
			regularS = preS[63:32];
		else if (fourth_funct3 == 2'b00)
			regularS = preS[31:0];
		else
			regularS = 0;
	wire [4:0] fifth_rd;
	wire [1:0] fifth_funct3;
	wire [63:0] mulRes;
	wire [63:0] preUnsigned;
	wire [63:0] real_op;
	PP2Adder fifth_level(
		.A(preS),
		.B(pre_op),
		.S(preUnsigned)
	);
	ResultBlockRegister unsignedRes(
		.Clk(Clk),
		.Reset(Reset),
		.third_op(pre_op),
		.in_funct3(fourth_funct3),
		.in_Rd(fourth_rd),
		.in_res(preUnsigned),
		.out_funct3(fifth_funct3),
		.res(mulRes),
		.Rd(fifth_rd),
		.almost_op(real_op)
	);
	always @(*) begin
		tempS = preS;
		if (B[31]) begin
			unsignedS = mulRes[63:32];
			tempU = mulRes;
		end
		else begin
			unsignedS = preS[63:32];
			tempU = 0;
		end
	end
endmodule
