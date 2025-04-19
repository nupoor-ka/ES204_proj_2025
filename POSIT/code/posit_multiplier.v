`timescale 1ns / 1ps

module posit_multiplier(
    input  [31:0] a, b,
    output reg [31:0] product,
    output reg error,
    output reg zero
);

    // Sign of the product
    wire sign = a[31] ^ b[31];

    // Regime extraction outputs
    wire signed [5:0] ka, kb;
    wire signed [5:0] k;
    wire [4:0] len_reg_a, len_reg_b;

    // Extracting regime values from inputs
    k_extractor kext1(.inp(a), .k_val(ka), .len_regime(len_reg_a));
    k_extractor kext2(.inp(b), .k_val(kb), .len_regime(len_reg_b));

    // Sum of regimes
    assign k = ka + kb;

    // Exponent and mantissa extraction
    wire [3:0] es1, es2;
    wire [26:0] man_val_1, man_val_2;

    mantissa_extractor man_ext1(.inp(a), .es(es1), .man_val(man_val_1), .len_regime(len_reg_a));
    mantissa_extractor man_ext2(.inp(b), .es(es2), .man_val(man_val_2), .len_regime(len_reg_b));

    // Mantissa multiplication
    wire carry_1;
    wire [55:0] man_final;

    mantissa_multiplier multip_man(.man_1(man_val_1), .man_2(man_val_2), .carry(carry_1), .man_final(man_final));

    // Exponent addition with carry from mantissa multiplication
    wire [4:0] es_tot = es1 + es2 + carry_1;
    wire [3:0] es_val = es_tot[3:0];
    wire carry = es_tot[4];

    // Final regime value including carry
    wire signed [5:0] k_final = k + carry;

    integer i;

    always @(*) begin
        product = 32'b0;
        error = 0;
        zero = 0;

        // Handle zero inputs
        if ((a == 32'b0) || (b == 32'b0)) begin
            zero = 1;
            product = 32'b0;
        end
        // Handle regime overflow/underflow
        else if ((k_final > 25) || (k_final < -26)) begin
            error = 1;
            product = 32'bx;
        end
        else begin
            product[31] = sign;

            if (k_final >= 0) begin
                // Positive regime bits
                for (i = 0; i <= k_final; i = i + 1)
                    product[30 - i] = 1'b1;

                product[30 - k_final - 1] = 1'b0;

                // Exponent bits
                for (i = 0; i < 4; i = i + 1)
                    product[30 - k_final - 2 - i] = es_val[3 - i];

                // Mantissa bits
                for (i = 0; i < 30 - k_final - 6; i = i + 1)
                    product[i] = man_final[53 - i];
            end
            else begin
                // Negative regime bits
                for (i = 0; i < -k_final; i = i + 1)
                    product[30 - i] = 1'b0;

                product[30 + k_final] = 1'b1;

                // Exponent bits
                for (i = 0; i < 4; i = i + 1)
                    product[30 + k_final - 1 - i] = es_val[3 - i];

                // Mantissa bits
                for (i = 0; i < 30 + k_final - 5; i = i + 1)
                    product[i] = man_final[53 - i];
            end
        end
    end

endmodule


module k_extractor(
    input [31:0] inp,
    output reg signed [5:0] k_val,
    output reg [4:0] len_regime
);
    integer i;
    reg found;

    always @(*) begin
        len_regime = 0;
        k_val = 0;
        found = 0;

        if (inp[30] == 1'b1) begin  // Positive regime val
            for (i = 29; i >= 0; i = i - 1) begin
                if (!found && inp[i] == 1'b0) begin
                    len_regime = 31 - i;
                    k_val = len_regime - 2;
                    found = 1;
                end
            end
        end else begin  // Negative regime avl
            for (i = 29; i >= 0; i = i - 1) begin
                if (!found && inp[i] == 1'b1) begin
                    len_regime = 31 - i;
                    k_val = -len_regime+1;
                    found = 1;
                end
            end
        end
    end
endmodule

module mantissa_extractor(
    input  [31:0] inp,
    output reg [3:0] es,
    output reg [26:0] man_val,
    input  [4:0] len_regime
);
    integer es_start;
    integer mantissa_start;
    reg [31:0] mask;
    reg [31:0] masked_bits;

    always @(*) begin
        es_start = 30 - len_regime; // Starting bit for exponent
        es = 4'b0;                  // Default values
        man_val = 27'b0;

        // Extract exponent bits if valid
        if (es_start >= 3) begin
            es = inp[es_start -: 4]; // Safe fixed-width extraction for exponent
        end else begin
            es = 4'b0;               // Invalid range, assign zero
        end

        // Calculate mantissa start bit
        mantissa_start = es_start - 4;

        if (mantissa_start < 0) begin
            // No bits available for mantissa, assign zero
            man_val = 27'b0;
        end else begin
            // Generate mask with lower (mantissa_start + 1) bits set to 1
            mask = (32'h1 << (mantissa_start + 1)) - 1;

            // Mask the input to extract only valid bits for mantissa
            masked_bits = inp & mask;

            // Shift left to align MSB and pad remaining LSBs with zeros
            man_val = masked_bits[26:0] << (27 - (mantissa_start + 1));
        end
    end
endmodule

module mantissa_multiplier(
    input  [26:0] man_1,
    input  [26:0] man_2,
    output wire carry,
    output wire [55:0] man_final
);
    wire [27:0] m1 = {1'b1, man_1}; 
    wire [27:0] m2 = {1'b1, man_2};
    wire [54:0] man_temp = m1 * m2;

    assign carry = ~man_temp[54];
    assign man_final = carry ? (man_temp << 1'b1) : man_temp;
endmodule
