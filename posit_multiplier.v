`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Authors: Nupoor Assudani, Vyomika Vasireddy
// 
// Create Date: 07.04.2025 23:49:42
// Design Name: Posit Multiplier
// Module Name: posit_multiplier
// Project Name: Comparing Posit and IEEE 754 Floating Point Numbers
// Target Devices: Basys 3 Xilinx
// Description: 
// Comparing computation cost and precision of final output for multiplication of posits and IEEE 754 floating point numbers
//////////////////////////////////////////////////////////////////////////////////


module posit_multiplier(a, b, product, error, zero);
input [31:0] a, b;
output reg [31:0] product;
output reg error, zero;
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
    if ((k>25)|(k<-26))
        begin
        product = 32'bx; 
        error = 1;
        end
    else if ((a==32'b0)|(b==32'b0))
        begin
        zero = 1;
        product = 32'b0;
        end
    else
        begin
        error = 0;
        if (k>0)
            begin
            for(i = 30;i>=30-k;i=i-1) product[i]=1;
            product[30-k-1]=0;
            product[31]=sign;
//             product[30-k-2]=es_val[3];
//             product[30-k-3]=es_val[2];
//             product[30-k-4]=es_val[1];
//             product[30-k-5]=es_val[0];
             for(i = 2; i<=5; i=i+1) product[30-k-i] = es_val[5-i];
            //product[30-k-2:30-k-5]=es_val[3:0];
            // for(j=30-k-6 ; j>=0; j=j-1) product[j]=man_final[31+j+k];
            man_start = 30-k-6;
            end
        else 
            begin
            for(i = 30;i>30+k;i=i-1) product[i]=0;
            product[30+k]=0;
            product[31]=sign;
//            product[30+k-1]=es_val[3];
//            product[30+k-2]=es_val[2];
//            product[30+k-3]=es_val[1];
//            product[30+k-4]=es_val[0];
            for(i = 1; i<=4; i=i+1) product[30+k-i] = es_val[4-i];
            
            //product[30+k-1:30+k-4]=es_val[3:0];
            // for(j=30+k-5 ; j>=0; j=j-1) product[j]=man_final[30+j-k];
            man_start = 30+k-5;
            end
        end
end

integer m,l,t;
reg [5:0] man_final_start;
always @(man_final)
    begin
        if((!error)&(!zero))
            begin
            begin :search_loop
            for(m=53;m>=0;m=m-1)
                begin
                    if(!man_final)
                        begin
                            man_final_start = m;
                            disable search_loop;
                        end
                        
                end
            for (t=man_start; t>=0; t=t-1)
            begin 
            product[t] = man_final[man_final_start-man_start+t];
            end
            end
            end
    end
endmodule


module mantissa_multiplier(man_1, man_2, carry, man_final, man_len_1, man_len_2);
input [26:0] man_1, man_2;
input man_len_1, man_len_2;
output carry;
output [55:0]man_final;
wire [27:0]m1 = {1'b1,man_1};
wire [27:0]m2= {1'b1,man_2};
wire [55:0]man_temp =m1*m2;
wire overflow = ~(man_temp[55]);
assign man_final = overflow ? (man_temp << 1'b1) : man_temp;
assign carry= overflow;
endmodule

module mantissa_extractor(inp, man_length, es, man_val);
input [31:0]inp;
output reg man_length, man_val;
output wire [3:0]es;
wire len_regime, k_val;
k_extractor k_extractor_1(inp, k_val, len_regime);
wire es_start= 31-1- len_regime;
wire [3:0]es=inp[es_start: es_start-3];
wire man_length=32-1-len_regime-4;
reg man_val=inp[es_start-4:0];
endmodule


module k_extractor(inp, k_val, len_regime);
input [31:0]inp;
output k_val;
output reg len_regime;
reg kk;
reg k_sign;
reg k_position;
integer i;
always@(inp)
begin
if (inp==32'b0)
    begin
    kk = 0;
    len_regime = 0;
    end
else
    begin
    if(inp[30])
        begin
        for(i = 29;i>=4;i = i - 1)
            begin
            if(!inp[i]) k_position <= i;
            end
        kk=30-k_position-1;
        end
    else
        begin
        for(i = 29;i>=4;i = i - 1)
            begin
            if(inp[i]) k_position <= i;
            end
        kk=(k_position-30);
        end
    len_regime = 31 - k_position;
    end
end
assign k_val = kk;
endmodule
