module REG_PIPLINE (in,clk,rst,enable,SEL,out);

parameter WIDTH = 18;

input [WIDTH-1:0] in;
input clk,rst,enable,SEL;
output reg [WIDTH-1:0] out;

reg [WIDTH-1:0] reg_out;

parameter RSTTYPE = "SYNC"; // synchronous or asynchronous rst

generate
    if(RSTTYPE == "SYNC") 
    begin
        always @(posedge clk ) 
        begin
            if(rst)
                reg_out <= 0;
            else if(enable)
                reg_out <= in;
        end
    end

    else if(RSTTYPE == "ASYNC") // "Async"
    begin
        always @(posedge clk , posedge rst) //Active High
        begin
            if(rst)
                reg_out <= 0;
            else if(enable)
                reg_out <= in;
        end
    end
endgenerate
// اختيار الداتا سواء من الخط او مباشره
// [REG] ---> 1 --> data From Register  | ---> 0 --> data Direct from Input

always @(*) begin
    case (SEL)
        1 : out = reg_out;
        0 : out = in;
        default : out = 0;
    endcase
end

endmodule //REG_PIPLINE
