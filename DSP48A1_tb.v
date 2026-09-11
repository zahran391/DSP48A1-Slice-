module DSP48A1_tb();

reg [17:0] A, B, D, BCIN;
reg [47:0] C, PCIN;
reg [7:0] OPMODE;

reg CARRYIN;
reg CECARRYIN, CEOPMODE;
reg RSTCARRYIN, RSTOPMODE;

reg CLK;
reg CEA, CEB, CEC, CEM, CEP, CED;
reg RSTA, RSTB, RSTC, RSTD, RSTM, RSTP;

wire CARRYOUT, CARRYOUTF;
wire [35:0] M;
wire [47:0] P, PCOUT;
wire [17:0] BCOUT;
// Expected Output "Like golden Model" That Compar With DUT 
reg [17:0] EXP_BCOUT;
reg [35:0] EXP_M;
reg [47:0] EXP_P;
reg [47:0] EXP_PCOUT;
reg EXP_CARRYOUT;
reg EXP_CARRYOUTF;

reg [17:0] PRE_EXP; // pre_add_sub
reg [35:0] M_EXP;  // Pre Multi 
reg [48:0] P_EXP; // Post 

integer i;

DSP48A1 DUT
(
    .A(A),.B(B),.C(C),.D(D),
    .CARRYIN(CARRYIN),.BCIN(BCIN),
    .clk(CLK),.OPMODE(OPMODE),

    .CEA(CEA),.CEB(CEB),.CEC(CEC),.CECARRYIN(CECARRYIN),.CED(CED),
    .CEM(CEM),.CEOPMODE(CEOPMODE),.CEP(CEP),

    .RSTA(RSTA),.RSTB(RSTB),.RSTC(RSTC),.RSTD(RSTD),.RSTM(RSTM),
    .RSTP(RSTP),.RSTCARRYIN(RSTCARRYIN),
    .RSTOPMODE(RSTOPMODE),

    .PCIN(PCIN),.CARRYOUT(CARRYOUT),
    .CARRYOUTF(CARRYOUTF),
    .M(M),.P(P),
    .PCOUT(PCOUT),.BCOUT(BCOUT)
);

initial 
begin
    CLK = 0;

    forever
    begin
     #1 CLK = ~CLK;
    end
end


task TEST_OPERATION;

    input [7:0] TEST_OPMODE;

    begin

        OPMODE = TEST_OPMODE;

        for(i = 0; i < 100; i = i + 1) 
        begin

            A = $random;
            B = $random;
            C = $random;
            D = $random;
            PCIN = $random;
            BCIN = $random;
            CARRYIN = $random;

      //  **هنعرف كل عمليه عندنا المتوقع عيكون ايه علشان نقارنه بنتيجه التصميم **
      // [TEST_OPMODE] ---> || هناخده ب التسلسل من الاول ل الاخر ونشوف مع كل حاله ايه المتوقغ ||
            // PRE-Add_sub Expected 
            if(TEST_OPMODE[6])
                PRE_EXP = D - B;
            else
                PRE_EXP = D + B;

            // MULTIPLIER
            M_EXP = {18'd0,A} * {18'd0,PRE_EXP};

            // POST-ADDER
            if(TEST_OPMODE[7] == 0) 
            begin

                case(TEST_OPMODE[3:2])

                    2'b00:
                        P_EXP = {13'd0,M_EXP};

                    2'b01:
                        P_EXP = {12'd0,M_EXP} + {1'b0,PCIN};

                    2'b10:
                        P_EXP = {12'd0,M_EXP} + {1'b0,P};

                    2'b11:
                        P_EXP = {12'd0,M_EXP} + {1'b0,C};
                endcase

                if(TEST_OPMODE[5])
                    P_EXP = P_EXP + 1'b1;

            end

            else begin

                case(TEST_OPMODE[3:2])

                    2'b00:
                        P_EXP = -{13'd0,M_EXP};

                    2'b01:
                        P_EXP = {1'b0,PCIN} - {13'd0,M_EXP};

                    2'b10:
                        P_EXP = {1'b0,P} - {13'd0,M_EXP};

                    2'b11:
                        P_EXP = {1'b0,C} - {13'd0,M_EXP};

                endcase

                if(TEST_OPMODE[5])
                    P_EXP = P_EXP - 1'b1;

            end


            EXP_BCOUT = PRE_EXP;
            EXP_M = M_EXP;
            EXP_P = P_EXP[47:0];
            EXP_PCOUT = P_EXP[47:0];
            EXP_CARRYOUT = P_EXP[48];
            EXP_CARRYOUTF = P_EXP[48];


            // Pipeline latency
            repeat(4) @(negedge CLK);

            // CHECK

            if((BCOUT !== EXP_BCOUT) ||(M !== EXP_M) ||(P !== EXP_P) ||(PCOUT !== EXP_PCOUT) ||
               (CARRYOUT !== EXP_CARRYOUT) ||(CARRYOUTF !== EXP_CARRYOUTF)) 
               begin

                $display("ERROR IN DESIGN");
                $display("OPMODE = %b", OPMODE);

                $display("A    = %d", A);
                $display("B    = %d", B);
                $display("C    = %d", C);
                $display("D    = %d", D);
                $display("PCIN = %d", PCIN);

                $display("*****************************************");

                $display("BCOUT : Expected = %d | Actual = %d",
                         EXP_BCOUT, BCOUT);

                $display("M     : Expected = %d | Actual = %d",
                         EXP_M, M);

                $display("P     : Expected = %d | Actual = %d",
                         EXP_P, P);

                $display("PCOUT : Expected = %d | Actual = %d",
                         EXP_PCOUT, PCOUT);

                $display("CARRYOUT : Expected = %b | Actual = %b",
                         EXP_CARRYOUT, CARRYOUT);

                $display("CARRYOUTF : Expected = %b | Actual = %b",
                         EXP_CARRYOUTF, CARRYOUTF);

                $display("*******************************************");

                $stop;
            end
        end
        $display("TEST PASSED : OPMODE = %b", TEST_OPMODE);
    end
endtask

// 1 > Active   For All REST   Signal 
// 2 > Deactive For All Enable Signal & Zero Input Initial  
// 3 > Deactive For All REST   Signal
// 4 > Active   For All Enable Signal To able Test 
initial begin
    RSTA       = 1;
    RSTB       = 1;
    RSTC       = 1;
    RSTD       = 1;
    RSTM       = 1;
    RSTP       = 1;
    RSTCARRYIN = 1;
    RSTOPMODE  = 1;

    CEA       = 0;
    CEB       = 0;
    CEC       = 0;
    CED       = 0;
    CEM       = 0;
    CEP       = 0;
    CECARRYIN = 0;
    CEOPMODE  = 0;

    A       = 0;
    B       = 0;
    C       = 0;
    D       = 0;
    PCIN    = 0;
    BCIN    = 0;
    CARRYIN = 0;
    OPMODE  = 0;

    repeat(3) @(negedge CLK);

    RSTA       = 0;
    RSTB       = 0;
    RSTC       = 0;
    RSTD       = 0;
    RSTM       = 0;
    RSTP       = 0;
    RSTCARRYIN = 0;
    RSTOPMODE  = 0;

    CEA       = 1;
    CEB       = 1;
    CEC       = 1;
    CED       = 1;
    CEM       = 1;
    CEP       = 1;
    CECARRYIN = 1;
    CEOPMODE  = 1;


    @(negedge CLK);

    // Test 1
    // ((D + B) * A) + PCIN + CIN

    TEST_OPERATION(8'b00110101);

    // Test 2
    // C + ((D + B) * A)

    TEST_OPERATION(8'b00011101);

    // Test 3
    // ((D - B) * A) + PCIN + CIN

    TEST_OPERATION(8'b01110101);


    $display("****************************************");
    $display("ALL TESTS PASSED SUCCESSFULLY *ZAHRAN*");
    $display("****************************************");

    $stop;

end
// Monitor 
initial 
begin

    $monitor("Time=%0t | OPMODE=%b | A=%d | B=%d | D=%d | BCOUT=%d | M=%d | P=%d | PCOUT=%d | CARRYOUT=%b",
             $time,OPMODE,A,B,D,BCOUT,M,P,PCOUT,CARRYOUT);
end

endmodule
