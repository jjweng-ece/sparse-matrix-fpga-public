"""Independent matrix numerics and canonical CSR-A; no RTL/FSM dependency."""
MASK32=(1<<32)-1


def check_matrix(x):
    if len(x)!=16 or any(not -128<=v<=127 for v in x):
        raise ValueError('expected 16 row-major signed INT8 entries')


def matmul(a,b,seeds=None):
    check_matrix(a);check_matrix(b)
    if seeds is None:seeds=[0]*16
    if len(seeds)!=16:raise ValueError('expected 16 seeds')
    return [(int(seeds[4*i+j])+sum(int(a[4*i+k])*int(b[4*k+j]) for k in range(4))) & MASK32
            for i in range(4) for j in range(4)]


def encode_csr(a):
    check_matrix(a)
    values=[];columns=[];pointers=[0]
    for i in range(4):
        for k in range(4):
            if a[4*i+k]:values.append(a[4*i+k]);columns.append(k)
        pointers.append(len(values))
    return values,columns,pointers


def decode_csr(values,columns,pointers):
    n=len(values)
    if n>16 or len(columns)!=n or len(pointers)!=5 or pointers[0]!=0 or pointers[-1]!=n:
        raise ValueError('invalid CSR header')
    a=[0]*16
    for i in range(4):
        lo,hi=pointers[i:i+2]
        if not 0<=lo<=hi<=n:raise ValueError('invalid row range')
        prev=-1
        for p in range(lo,hi):
            if not -128<=values[p]<=127 or values[p]==0 or not prev<columns[p]<4:
                raise ValueError('CSR must be nonzero and strictly ordered per row')
            prev=columns[p];a[4*i+columns[p]]=values[p]
    return a


def matmul_csr(values,columns,pointers,b,seeds=None):
    # A separate sparse arithmetic traversal, checked against dense matmul.
    decode_csr(values,columns,pointers);check_matrix(b)
    out=list(seeds) if seeds is not None else [0]*16
    if len(out)!=16:raise ValueError('expected 16 seeds')
    for i in range(4):
        for p in range(pointers[i],pointers[i+1]):
            for j in range(4):
                out[4*i+j]=(int(out[4*i+j])+int(values[p])*int(b[4*columns[p]+j])) & MASK32
    return [x & MASK32 for x in out]
