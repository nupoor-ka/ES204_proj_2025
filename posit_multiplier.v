`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.04.2025 23:49:42
// Design Name: 
// Module Name: posit_multiplier
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module posit_multiplier(a,b,product);
input [31:0] a, b;
output reg [31:0] product;
reg k_final;
reg k_temp_1;
//sign bit
assign sign= (a[31]^b[31]);
//extracting values regarding regime
wire k, ka, kb, len_reg_a, len_reg_b;
k_extractor kext1(a, ka, len_reg_a);
k_extractor kext2(b, kb, len_reg_b);

//extracting values regarding mantissa
wire es1, es2, man_length_1, man_length_2, man_val_1, man_val_2;
mantissa_extractor man_ext1(a, man_length_1, es1, man_val_1);
mantissa_extractor man_ext2(b, man_length_2, es2, man_val_2);

//multiplying the mantissa term
wire [55:0]man_final;
wire carry_1;
mantissa_multiplier multip_man(man_val_1, man_val_2, carry_1, man_final, man_length_1, man_length_2);

wire [4:0]es_tot;
assign es_tot=es1+es2+carry_1;
wire [3:0]es_val;
wire carry= es_tot[4];
assign es_val= es_tot[3:0];
assign k=ka+kb+carry;
reg man_start;
integer i,j;
always @(k)
begin
if (k>0)
    begin
    for(i = 30;i>=30-k;i=i-1) product[i]=1;
    product[30-k-1]=0;
    product[31]=sign;
    // product[30-k-2]=es_val[3];
    // product[30-k-3]=es_val[2];
    // product[30-k-4]=es_val[1];
    // product[30-k-5]=es_val[0];
    product[30-k-2:30-k-5]=es_val[3:0];
    // for(j=30-k-6 ; j>=0; j=j-1) product[j]=man_final[31+j+k];
    man_start = 30-k-6;
    end
else 
    begin
    for(i = 30;i>30+k;i=i-1) product[i]=0;
    product[30+k]=0;
    product[31]=sign;
    // product[30+k-1]=es_val[3];
    // product[30+k-2]=es_val[2];
    // product[30+k-3]=es_val[1];
    // product[30+k-4]=es_val[0];
    product[30+k-1:30+k-4]=es_val[3:0];
    // for(j=30+k-5 ; j>=0; j=j-1) product[j]=man_final[30+j-k];
    man_start = 30+k-5;
    end
end

integer k,l;
reg man_final_start;
always @(man_final)
    begin
        for(k=53;k>=0;k=k-1)
            begin
                if(!man_final)
                    begin
                        man_final_start = k;
                        break
                    end
            end
        product[man_start:0] = man_final[man_final_start:(man_final_start-man_start)];
    end

// need to add something to strip 1st character from mantissa, this would be the 0 or 1
// strip leading zeroes from mantissa
// truncate mantissa to fit in man_len
// write mantissa to man_start till 0

endmodule

module k_extractor(inp, k_val, len_regime);
input [31:0]inp;
output reg k_val, len_regime;
reg k_sign;
reg k_position;
always@(inp)
begin
if(inp[30])
    begin
    for(i = 29;i>=4;i = i - 1)
        begin
        if(!inp[i]) k_position <= i;
        end
    k_val=30-k_position-1;
    end
else
    begin
    for(i = 29;i>=4;i = i - 1)
        begin
        if(inp[i]) k_position <= i;
        end
    k_val=(k_position-30);
    end
len_regime=31-k_position;
end

module mantissa_extractor(inp, man_length, es, man_val);
input inp[31:0];
output man_length, man_val;
output reg es[3:0];
reg len_regime, k_val;
k_extractor k_extractor_1(inp, k_val, len_regime);
reg es_start= 31-1- len_regime;
assign es=inp[es_start: es_start-3];
assign man_length=32-1-len_regime-4;
assign man_val=inp[es_start-4:0];
endmodule

module mantissa_multiplier(man_1, man_2, carry, man_final, man_len_1, man_len_2);
input [27:0] man_1, man_2;
input man_len_1, man_len_2;
output carry;
output [55:0]man_final;
wire m1[27:0] = {1,man_1};
wire m2[27:0]= {1,man_2};
wire man_temp[55:0] =m1*m2;
wire overflow = ~(man_temp[55]);
assign man_final = overflow ? (man_temp << 1'b1) : man_temp;
assign carry= overflow;
endmodule


