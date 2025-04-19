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
