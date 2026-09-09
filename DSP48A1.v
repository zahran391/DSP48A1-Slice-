module DSP48A1 
(
    input [17:0]A,B,D,
    input [47:0]C,

    input clk,CARRYIN,

    input [7:0]OPMODE,

    input RSTA,RSTB,RSTM,RSTP,RSTC,RSTD,RSTCARRYIN,RSTOPMODE,

    input CEA,CEB,CEM,CEP,CED,CECARRYIN,CEOPMODE,CEC,

    input [47:0]PCIN,
    input [17:0]BCIN,  // Cascaded B from another DSP

    output [17:0]BCOUT,
    output [47:0]PCOUT,P,
    output [35:0]M,

    output CARRYOUT,CARRYOUTF

);

parameter A0REG = 0; // A0 with no register
parameter A1REG = 1; // A1 with register

parameter B0REG = 0; // B0 with no register
parameter B1REG = 1; // B1 with register

parameter CREG = 1; // Default : C with register
parameter DREG = 1; // Default : D with register
parameter MREG = 1; // Default : M with register
parameter PREG = 1; // Default : P with register
parameter CARRYINREG = 1; // Default : CARRYIN with register
parameter CARRYOUTREG = 1; // Default : CARRYOUT with register
parameter OPMODEREG = 1; // Default : OPMODE with register

parameter CARRYINSEL = "OPMODES";
// to set Value of CARRYIN = OPMODE[5] or remains input "CARRYIN"

parameter B_INPUT = "DIRECT";
// to define the value of B remains input "DIRECT" or BCIN "CASCADE" from another DSP

parameter RSTTYPE = "SYN"; // synchronous or asynchronous rst

// the outputs of Part One
wire [17:0]A0_OUT,B0_OUT,D_OUT;
wire [47:0]C_OUT;

// B_INPUT Path
wire [17:0]B_IN;

generate
    if(B_INPUT == "DIRECT")
        assign B_IN = B;
    else if(B_INPUT == "CASCADE")
        assign B_IN = BCIN;
    else
        assign B_IN = 0;
endgenerate

// نستدعي موديول الريجيسترات مع كل ريجيستر في كل جزء 
// انا وضعت البارميتر ب 18 فاي مدخل ب 18 مش هنكتب ال width
REG_PIPLINE A_REG_OUT 
(
    .in(A),
    .clk(clk),
    .rst(RSTA),
    .enable(CEA),
    .SEL(A0REG),
    .out(A0_OUT)
);

REG_PIPLINE B_REG_OUT 
(
    .in(B_IN),
    .clk(clk),
    .rst(RSTB),
    .enable(CEB),
    .SEL(B0REG),
    .out(B0_OUT)
);

REG_PIPLINE #(.WIDTH(48)) C_REG_OUT 
(
    .in(C),
    .clk(clk),
    .rst(RSTC),
    .enable(CEC),
    .SEL(CREG),
    .out(C_OUT)
);

REG_PIPLINE D_REG_OUT 
(
    .in(D),
    .clk(clk),
    .rst(RSTD),
    .enable(CED),
    .SEL(DREG),
    .out(D_OUT)
);

//Part 2
// OPMODE out
wire [7:0]OPMODE_OUT;

REG_PIPLINE #(.WIDTH(8)) OPMODE_REG_OUT 
(
    .in(OPMODE),
    .clk(clk),
    .rst(RSTOPMODE),
    .enable(CEOPMODE),
    .SEL(OPMODEREG),
    .out(OPMODE_OUT)
);

// PRE-ADD/SUB OUTPUT
reg [17:0] PRE_ADD_SUB;

// PRE-ADD/SUB SEL
always @(*) begin
    if(OPMODE_OUT[6])
        PRE_ADD_SUB = D_OUT - B0_OUT;
    else
        PRE_ADD_SUB = D_OUT + B0_OUT;
end

// B1 | A1
// Input of B1_REG
reg [17:0]B1_REG_IN;

// Multiplier Inputs SEL --> هياخد من خرج الريجيستر ولا مباشره من ال B
always @(*) 
begin
    if(OPMODE_OUT[4])
        B1_REG_IN = PRE_ADD_SUB;
    else
        B1_REG_IN = B0_OUT;
end

// output of A1_REG
wire [17:0]A1_OUT;

// reg mux
REG_PIPLINE B1_REG_OUT 
(
    .in(B1_REG_IN),
    .clk(clk),
    .rst(RSTB),
    .enable(CEB),
    .SEL(B1REG),
    .out(BCOUT)
);

REG_PIPLINE A1_REG_OUT 
(
    .in(A0_OUT),
    .clk(clk),
    .rst(RSTA),
    .enable(CEA),
    .SEL(A1REG),
    .out(A1_OUT)
);

// Part 3
// M_REG_IN
wire [35:0]M_OUT;

// Multiplier 
assign M_OUT = A1_OUT * BCOUT;

// نستدعي مودبول الربجيسترات 
REG_PIPLINE #(.WIDTH(36)) M_REG_OUT 
(
    .in(M_OUT),
    .clk(clk),
    .rst(RSTM),
    .enable(CEM),
    .SEL(MREG),
    .out(M)
);

// CARRYIN OUT
wire CARRYIN_OUT;

// CARRYIN SEL --> رسمه الي في الاسفل والي هتوضح ايه الي هيكون دخل cin 
generate
    if(CARRYINSEL == "OPMODES")
        assign CARRYIN_OUT = OPMODE_OUT[5];
    else if(CARRYINSEL == "CARRYIN")
        assign CARRYIN_OUT = CARRYIN;
endgenerate

// CUUTPUT OF CY1
wire CIN;

// MUX REG CARRYIN
REG_PIPLINE #(.WIDTH(1)) CY1
(
    .in(CARRYIN_OUT),
    .clk(clk),
    .rst(RSTCARRYIN),
    .enable(CECARRYIN),
    .SEL(CARRYINREG),
    .out(CIN)
);

// Part 4
// POST_ADDER/SUB INPUTS
reg [47:0] X_OUT,Z_OUT;

// POST_ADDER/SUB OUTPUTS
reg [47:0] P_IN;

reg CARRYOUT_IN;

    wire [47:0] ABD_Conc; // D:A:B Concatenated
    wire [47:0] Mul_Out_Pip_Etended; //extended with zeros.

    assign ABD_Conc = {D_OUT[11:0], A1_OUT, BCOUT};
    assign Mul_Out_Pip_Etended = {12'h000, M};

// POST_ADD/SUB SEL Concatination Output {carryoutput and P_IN}
always @(*) begin
    if(~OPMODE_OUT[7])
        { CARRYOUT_IN , P_IN } = X_OUT + Z_OUT + { 47'd0, CIN };
    else
        { CARRYOUT_IN , P_IN } = X_OUT - ( Z_OUT + { 47'd0, CIN } );
end

// CARRY OUT REG موجود في اعلى التصميم 
REG_PIPLINE #(.WIDTH(1)) CY0_carry
(
    .in(CARRYOUT_IN),
    .clk(clk),
    .rst(RSTCARRYIN),
    .enable(CECARRYIN),
    .SEL(CARRYOUTREG),
    .out(CARRYOUT)
);

assign CARRYOUTF = CARRYOUT;

// MUX_X
always @(*) begin
    case(OPMODE_OUT[1:0])
        2'b00 : X_OUT = 0;
        2'b01 : X_OUT = Mul_Out_Pip_Etended;
        2'b10 : X_OUT = P; 
        2'b11 : X_OUT = ABD_Conc; // Concatenated D:A:B
        default : X_OUT = 1'b0;
    endcase
end

// MUX_Z
always @(*) begin
    case(OPMODE_OUT[3:2])
        2'b00 : Z_OUT = 0;
        2'b01 : Z_OUT = PCIN;
        2'b10 : Z_OUT = P; 
        2'b11 : Z_OUT = C_OUT;
        default : Z_OUT = 1'b0; 
    endcase
end

// P REG 
REG_PIPLINE #(.WIDTH(48)) P_REG_OUT 
(
    .in(P_IN),
    .clk(clk),
    .rst(RSTP),
    .enable(CEP),
    .SEL(PREG),
    .out(P)
);

assign PCOUT = P;

endmodule 
