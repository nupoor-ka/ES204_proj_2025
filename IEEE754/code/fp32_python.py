a=input("enter string1: ")
b=input("enter string2: ")
sign1=int(a[0])
es1=a[1:9]
mantissa1=a[9:32]
sign2=int(b[0])
es2=b[1:9]
mantissa2=b[9:32]
bias=127  #2^7-1
def bin_decimal(p):
    s=0
    for i in range(len(p)):
        s=s+(2**(len(p)-1-i))*int(p[i])
    return s
def decimal_bin(q):
  s = ''
  while q!=0:
    rem = q%2
    s = str(rem) + s
    q = q//2
  return s

e1=bin_decimal(es1)
e2=bin_decimal(es2)
y1=float(bin_decimal(mantissa1))/2**23
y2=float(bin_decimal(mantissa2))/2**23
sign=(sign1^sign2)
product=((-1)**sign) * (2**(e1+e2-2*bias)) * (1+ (y1+y2)+ y1*y2)
print(product)
