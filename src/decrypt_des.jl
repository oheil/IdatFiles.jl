
macro READ_64BIT_DATA(data, left, right)
    quote
        ldata = UInt32.($(esc(data)))
        $(esc(left)) = (ldata[1] << 24) | (ldata[2] << 16) | (ldata[3] << 8) | ldata[4] 
        $(esc(right)) = (ldata[5] << 24) | (ldata[6] << 16) | (ldata[7] << 8) | ldata[8]
    end
end

macro WRITE_64BIT_DATA(data, left, right)
    quote
        $(esc(data))[1] = ( $(esc(left)) >> 24) & 0xff
        $(esc(data))[2] = ( $(esc(left)) >> 16) & 0xff
        $(esc(data))[3] = ( $(esc(left)) >> 8) & 0xff
        $(esc(data))[4] =  $(esc(left)) & 0xff
        $(esc(data))[5] = ( $(esc(right)) >> 24) & 0xff
        $(esc(data))[6] = ( $(esc(right)) >> 16) & 0xff
        $(esc(data))[7] = ( $(esc(right)) >> 8) & 0xff
        $(esc(data))[8] =  $(esc(right)) & 0xff
    end
end

macro DO_PERMUTATION(a, temp, b, offset, mask)
    quote
        $(esc(temp)) = ( ( $(esc(a)) >> $(esc(offset)) ) ⊻ $(esc(b)) ) & $(esc(mask))
        $(esc(b)) ⊻= $(esc(temp))
        $(esc(a)) ⊻= $(esc(temp)) << $(esc(offset))
    end
end

macro INITIAL_PERMUTATION(left, temp, right)
    quote
        @DO_PERMUTATION($(esc(left)), $(esc(temp)), $(esc(right)), 4, 0x0f0f0f0f)
        @DO_PERMUTATION($(esc(left)), $(esc(temp)), $(esc(right)), 16, 0x0000ffff)
        @DO_PERMUTATION($(esc(right)), $(esc(temp)), $(esc(left)), 2, 0x33333333)
        @DO_PERMUTATION($(esc(right)), $(esc(temp)), $(esc(left)), 8, 0x00ff00ff)
        $(esc(right)) =  ($(esc(right)) << 1) | ($(esc(right)) >> 31)
        $(esc(temp))  =  ($(esc(left)) ⊻ $(esc(right))) & 0xaaaaaaaa
        $(esc(right)) ⊻= $(esc(temp))
        $(esc(left))  ⊻= $(esc(temp))
        $(esc(left))  =  ($(esc(left)) << 1) | ($(esc(left)) >> 31)
    end
end

macro FINAL_PERMUTATION(left, temp, right)
    quote
        $(esc(left))  =  ( $(esc(left)) << 31) | ( $(esc(left)) >> 1)
        $(esc(temp))  =  ( $(esc(left)) ⊻ $(esc(right)) ) & 0xaaaaaaaa
        $(esc(left))  ⊻= $(esc(temp))
        $(esc(right)) ⊻= $(esc(temp))
        $(esc(right))  =  ( $(esc(right)) << 31) | ( $(esc(right)) >> 1)
        @DO_PERMUTATION($(esc(right)), $(esc(temp)), $(esc(left)), 8, 0x00ff00ff)
        @DO_PERMUTATION($(esc(right)), $(esc(temp)), $(esc(left)), 2, 0x33333333)
        @DO_PERMUTATION($(esc(left)), $(esc(temp)), $(esc(right)), 16, 0x0000ffff)
        @DO_PERMUTATION($(esc(left)), $(esc(temp)), $(esc(right)), 4, 0x0f0f0f0f)
    end
end

macro DES_ROUND(from, to, work, subkey, subkey_index)
    quote
        $(esc(work)) = $(esc(from)) ⊻ $(esc(subkey))[$(esc(subkey_index))+=1]
        $(esc(to)) ⊻= $(esc(sbox8))[1 + ($(esc(work)) & 0x3f)]
        $(esc(to)) ⊻= $(esc(sbox6))[1 + ( ($(esc(work)) >> 8) & 0x3f)]
        $(esc(to)) ⊻= $(esc(sbox4))[1 + ( ($(esc(work)) >> 16) & 0x3f)]
        $(esc(to)) ⊻= $(esc(sbox2))[1 + ( ($(esc(work)) >> 24) & 0x3f)]
        $(esc(work)) = ($(esc(from)) << 28) | ($(esc(from)) >> 4) ⊻ $(esc(subkey))[$(esc(subkey_index))+=1]
        $(esc(to)) ⊻= $(esc(sbox7))[1 + ($(esc(work)) & 0x3f)]
        $(esc(to)) ⊻= $(esc(sbox5))[1 + ( ($(esc(work)) >> 8) & 0x3f)]
        $(esc(to)) ⊻= $(esc(sbox3))[1 + ( ($(esc(work)) >> 16) & 0x3f)]
        $(esc(to)) ⊻= $(esc(sbox1))[1 + ( ($(esc(work)) >> 24) & 0x3f)]
    end
end

leftkey_swap=Array{UInt32,1}([
    0x00000000, 0x00000001, 0x00000100, 0x00000101,
    0x00010000, 0x00010001, 0x00010100, 0x00010101,
    0x01000000, 0x01000001, 0x01000100, 0x01000101,
    0x01010000, 0x01010001, 0x01010100, 0x01010101
])

rightkey_swap=Array{UInt32,1}([
    0x00000000, 0x01000000, 0x00010000, 0x01010000,
    0x00000100, 0x01000100, 0x00010100, 0x01010100,
    0x00000001, 0x01000001, 0x00010001, 0x01010001,
    0x00000101, 0x01000101, 0x00010101, 0x01010101,
])

encrypt_rotate_tab=Array{UInt8,1}([
    1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1
])

sbox1=Array{UInt32,1}([
    0x01010400, 0x00000000, 0x00010000, 0x01010404, 0x01010004, 0x00010404,
    0x00000004, 0x00010000, 0x00000400, 0x01010400, 0x01010404, 0x00000400,
    0x01000404, 0x01010004, 0x01000000, 0x00000004, 0x00000404, 0x01000400,
    0x01000400, 0x00010400, 0x00010400, 0x01010000, 0x01010000, 0x01000404,
    0x00010004, 0x01000004, 0x01000004, 0x00010004, 0x00000000, 0x00000404,
    0x00010404, 0x01000000, 0x00010000, 0x01010404, 0x00000004, 0x01010000,
    0x01010400, 0x01000000, 0x01000000, 0x00000400, 0x01010004, 0x00010000,
    0x00010400, 0x01000004, 0x00000400, 0x00000004, 0x01000404, 0x00010404,
    0x01010404, 0x00010004, 0x01010000, 0x01000404, 0x01000004, 0x00000404,
    0x00010404, 0x01010400, 0x00000404, 0x01000400, 0x01000400, 0x00000000,
    0x00010004, 0x00010400, 0x00000000, 0x01010004
])
sbox2=Array{UInt32,1}([
    0x80108020, 0x80008000, 0x00008000, 0x00108020, 0x00100000, 0x00000020,
    0x80100020, 0x80008020, 0x80000020, 0x80108020, 0x80108000, 0x80000000,
    0x80008000, 0x00100000, 0x00000020, 0x80100020, 0x00108000, 0x00100020,
    0x80008020, 0x00000000, 0x80000000, 0x00008000, 0x00108020, 0x80100000,
    0x00100020, 0x80000020, 0x00000000, 0x00108000, 0x00008020, 0x80108000,
    0x80100000, 0x00008020, 0x00000000, 0x00108020, 0x80100020, 0x00100000,
    0x80008020, 0x80100000, 0x80108000, 0x00008000, 0x80100000, 0x80008000,
    0x00000020, 0x80108020, 0x00108020, 0x00000020, 0x00008000, 0x80000000,
    0x00008020, 0x80108000, 0x00100000, 0x80000020, 0x00100020, 0x80008020,
    0x80000020, 0x00100020, 0x00108000, 0x00000000, 0x80008000, 0x00008020,
    0x80000000, 0x80100020, 0x80108020, 0x00108000
])
sbox3=Array{UInt32,1}([
    0x00000208, 0x08020200, 0x00000000, 0x08020008, 0x08000200, 0x00000000,
    0x00020208, 0x08000200, 0x00020008, 0x08000008, 0x08000008, 0x00020000,
    0x08020208, 0x00020008, 0x08020000, 0x00000208, 0x08000000, 0x00000008,
    0x08020200, 0x00000200, 0x00020200, 0x08020000, 0x08020008, 0x00020208,
    0x08000208, 0x00020200, 0x00020000, 0x08000208, 0x00000008, 0x08020208,
    0x00000200, 0x08000000, 0x08020200, 0x08000000, 0x00020008, 0x00000208,
    0x00020000, 0x08020200, 0x08000200, 0x00000000, 0x00000200, 0x00020008,
    0x08020208, 0x08000200, 0x08000008, 0x00000200, 0x00000000, 0x08020008,
    0x08000208, 0x00020000, 0x08000000, 0x08020208, 0x00000008, 0x00020208,
    0x00020200, 0x08000008, 0x08020000, 0x08000208, 0x00000208, 0x08020000,
    0x00020208, 0x00000008, 0x08020008, 0x00020200
])
sbox4=Array{UInt32,1}([
    0x00802001, 0x00002081, 0x00002081, 0x00000080, 0x00802080, 0x00800081,
    0x00800001, 0x00002001, 0x00000000, 0x00802000, 0x00802000, 0x00802081,
    0x00000081, 0x00000000, 0x00800080, 0x00800001, 0x00000001, 0x00002000,
    0x00800000, 0x00802001, 0x00000080, 0x00800000, 0x00002001, 0x00002080,
    0x00800081, 0x00000001, 0x00002080, 0x00800080, 0x00002000, 0x00802080,
    0x00802081, 0x00000081, 0x00800080, 0x00800001, 0x00802000, 0x00802081,
    0x00000081, 0x00000000, 0x00000000, 0x00802000, 0x00002080, 0x00800080,
    0x00800081, 0x00000001, 0x00802001, 0x00002081, 0x00002081, 0x00000080,
    0x00802081, 0x00000081, 0x00000001, 0x00002000, 0x00800001, 0x00002001,
    0x00802080, 0x00800081, 0x00002001, 0x00002080, 0x00800000, 0x00802001,
    0x00000080, 0x00800000, 0x00002000, 0x00802080
])
sbox5=Array{UInt32,1}([
    0x00000100, 0x02080100, 0x02080000, 0x42000100, 0x00080000, 0x00000100,
    0x40000000, 0x02080000, 0x40080100, 0x00080000, 0x02000100, 0x40080100,
    0x42000100, 0x42080000, 0x00080100, 0x40000000, 0x02000000, 0x40080000,
    0x40080000, 0x00000000, 0x40000100, 0x42080100, 0x42080100, 0x02000100,
    0x42080000, 0x40000100, 0x00000000, 0x42000000, 0x02080100, 0x02000000,
    0x42000000, 0x00080100, 0x00080000, 0x42000100, 0x00000100, 0x02000000,
    0x40000000, 0x02080000, 0x42000100, 0x40080100, 0x02000100, 0x40000000,
    0x42080000, 0x02080100, 0x40080100, 0x00000100, 0x02000000, 0x42080000,
    0x42080100, 0x00080100, 0x42000000, 0x42080100, 0x02080000, 0x00000000,
    0x40080000, 0x42000000, 0x00080100, 0x02000100, 0x40000100, 0x00080000,
    0x00000000, 0x40080000, 0x02080100, 0x40000100
])
sbox6=Array{UInt32,1}([
    0x20000010, 0x20400000, 0x00004000, 0x20404010, 0x20400000, 0x00000010,
    0x20404010, 0x00400000, 0x20004000, 0x00404010, 0x00400000, 0x20000010,
    0x00400010, 0x20004000, 0x20000000, 0x00004010, 0x00000000, 0x00400010,
    0x20004010, 0x00004000, 0x00404000, 0x20004010, 0x00000010, 0x20400010,
    0x20400010, 0x00000000, 0x00404010, 0x20404000, 0x00004010, 0x00404000,
    0x20404000, 0x20000000, 0x20004000, 0x00000010, 0x20400010, 0x00404000,
    0x20404010, 0x00400000, 0x00004010, 0x20000010, 0x00400000, 0x20004000,
    0x20000000, 0x00004010, 0x20000010, 0x20404010, 0x00404000, 0x20400000,
    0x00404010, 0x20404000, 0x00000000, 0x20400010, 0x00000010, 0x00004000,
    0x20400000, 0x00404010, 0x00004000, 0x00400010, 0x20004010, 0x00000000,
    0x20404000, 0x20000000, 0x00400010, 0x20004010
])
sbox7=Array{UInt32,1}([
    0x00200000, 0x04200002, 0x04000802, 0x00000000, 0x00000800, 0x04000802,
    0x00200802, 0x04200800, 0x04200802, 0x00200000, 0x00000000, 0x04000002,
    0x00000002, 0x04000000, 0x04200002, 0x00000802, 0x04000800, 0x00200802,
    0x00200002, 0x04000800, 0x04000002, 0x04200000, 0x04200800, 0x00200002,
    0x04200000, 0x00000800, 0x00000802, 0x04200802, 0x00200800, 0x00000002,
    0x04000000, 0x00200800, 0x04000000, 0x00200800, 0x00200000, 0x04000802,
    0x04000802, 0x04200002, 0x04200002, 0x00000002, 0x00200002, 0x04000000,
    0x04000800, 0x00200000, 0x04200800, 0x00000802, 0x00200802, 0x04200800,
    0x00000802, 0x04000002, 0x04200802, 0x04200000, 0x00200800, 0x00000000,
    0x00000002, 0x04200802, 0x00000000, 0x00200802, 0x04200000, 0x00000800,
    0x04000002, 0x04000800, 0x00000800, 0x00200002
])
sbox8=Array{UInt32,1}([
    0x10001040, 0x00001000, 0x00040000, 0x10041040, 0x10000000, 0x10001040,
    0x00000040, 0x10000000, 0x00040040, 0x10040000, 0x10041040, 0x00041000,
    0x10041000, 0x00041040, 0x00001000, 0x00000040, 0x10040000, 0x10000040,
    0x10001000, 0x00001040, 0x00041000, 0x00040040, 0x10040040, 0x10041000,
    0x00001040, 0x00000000, 0x00000000, 0x10040040, 0x10000040, 0x10001000,
    0x00041040, 0x00040000, 0x00041040, 0x00040000, 0x10041000, 0x00001000,
    0x00000040, 0x10040040, 0x00001000, 0x00041040, 0x10001000, 0x00000040,
    0x10000040, 0x10040000, 0x10040040, 0x10000000, 0x00040000, 0x10001040,
    0x00000000, 0x10041040, 0x00040040, 0x10000040, 0x10040000, 0x10001000,
    0x10001040, 0x00000000, 0x10041040, 0x00041000, 0x00041000, 0x00001040,
    0x00001040, 0x00040040, 0x10000000, 0x10041000
])

struct Gl_des_ctx
    encrypt_subkeys::Array{UInt32,1}
    decrypt_subkeys::Array{UInt32,1}
    function Gl_des_ctx()
        encrypt_subkeys=zeros(UInt32,32)
        decrypt_subkeys=zeros(UInt32,32)
        new(encrypt_subkeys,decrypt_subkeys)
    end
end

function des_key_schedule!( key::Array{UInt8,1}, subkey::Array{UInt32,1})
    @READ_64BIT_DATA(key, left, right)
    @DO_PERMUTATION(right, work, left, 4, 0x0f0f0f0f)
    @DO_PERMUTATION(right, work, left, 0, 0x10101010)
    left = (
        (leftkey_swap[1+((left >> 0) & 0xf)] << 3) | 
        (leftkey_swap[1+((left >> 8) & 0xf)] << 2) |
        (leftkey_swap[1+((left >> 16) & 0xf)] << 1) |
        (leftkey_swap[1+((left >> 24) & 0xf)]) | 
        (leftkey_swap[1+((left >> 5) & 0xf)] << 7) |
        (leftkey_swap[1+((left >> 13) & 0xf)] << 6) |
        (leftkey_swap[1+((left >> 21) & 0xf)] << 5) |
        (leftkey_swap[1+((left >> 29) & 0xf)] << 4)
        )
    left &= 0x0fffffff
    right = (
        (rightkey_swap[1+((right >> 1) & 0xf)] << 3)
        | (rightkey_swap[1+((right >> 9) & 0xf)] << 2)
        | (rightkey_swap[1+((right >> 17) & 0xf)] << 1)
        | (rightkey_swap[1+((right >> 25) & 0xf)])
        | (rightkey_swap[1+((right >> 4) & 0xf)] << 7)
        | (rightkey_swap[1+((right >> 12) & 0xf)] << 6)
        | (rightkey_swap[1+((right >> 20) & 0xf)] << 5)
        | (rightkey_swap[1+((right >> 28) & 0xf)] << 4)
        )
    right &= 0x0fffffff
    for round in 1:16
        left = ((left << encrypt_rotate_tab[round])
            | (left >> (28 - encrypt_rotate_tab[round]))) & 0x0fffffff
        right = ((right << encrypt_rotate_tab[round])
            | (right >> (28 - encrypt_rotate_tab[round]))) & 0x0fffffff
        subkey[2round-1] = (((left << 4) & 0x24000000)
            | ((left << 28) & 0x10000000)
            | ((left << 14) & 0x08000000)
            | ((left << 18) & 0x02080000)
            | ((left << 6) & 0x01000000)
            | ((left << 9) & 0x00200000)
            | ((left >> 1) & 0x00100000)
            | ((left << 10) & 0x00040000)
            | ((left << 2) & 0x00020000)
            | ((left >> 10) & 0x00010000)
            | ((right >> 13) & 0x00002000)
            | ((right >> 4) & 0x00001000)
            | ((right << 6) & 0x00000800)
            | ((right >> 1) & 0x00000400)
            | ((right >> 14) & 0x00000200)
            | (right & 0x00000100)
            | ((right >> 5) & 0x00000020)
            | ((right >> 10) & 0x00000010)
            | ((right >> 3) & 0x00000008)
            | ((right >> 18) & 0x00000004)
            | ((right >> 26) & 0x00000002)
            | ((right >> 24) & 0x00000001))
        subkey[2round] = (((left << 15) & 0x20000000)
            | ((left << 17) & 0x10000000)
            | ((left << 10) & 0x08000000)
            | ((left << 22) & 0x04000000)
            | ((left >> 2) & 0x02000000)
            | ((left << 1) & 0x01000000)
            | ((left << 16) & 0x00200000)
            | ((left << 11) & 0x00100000)
            | ((left << 3) & 0x00080000)
            | ((left >> 6) & 0x00040000)
            | ((left << 15) & 0x00020000)
            | ((left >> 4) & 0x00010000)
            | ((right >> 2) & 0x00002000)
            | ((right << 8) & 0x00001000)
            | ((right >> 14) & 0x00000808)
            | ((right >> 9) & 0x00000400)
            | ((right) & 0x00000200)
            | ((right << 7) & 0x00000100)
            | ((right >> 7) & 0x00000020)
            | ((right >> 3) & 0x00000011)
            | ((right << 2) & 0x00000004)
            | ((right >> 21) & 0x00000002))
    end
end

function gl_des_setkey!(context::Gl_des_ctx,key::Array{UInt8,1})
    des_key_schedule!(key,context.encrypt_subkeys)
    for i in 1:2:31
        context.decrypt_subkeys[i] = context.encrypt_subkeys[32-i]
        context.decrypt_subkeys[i+1] = context.encrypt_subkeys[32-i+1]
    end
end

function gl_des_ecb_crypt!(context::Gl_des_ctx, from::Array{UInt8,1}, to::Array{UInt8,1}, mode::Bool)
    keys = mode ? context.decrypt_subkeys : context.encrypt_subkeys
    @READ_64BIT_DATA(from, left, right)
    @INITIAL_PERMUTATION(left, work, right)
    keys_index=0
    @DES_ROUND(right, left, work, keys, keys_index) 
    @DES_ROUND(left, right, work, keys, keys_index)
    @DES_ROUND(right, left, work, keys, keys_index)
    @DES_ROUND(left, right, work, keys, keys_index)
    @DES_ROUND(right, left, work, keys, keys_index)
    @DES_ROUND(left, right, work, keys, keys_index)
    @DES_ROUND(right, left, work, keys, keys_index)
    @DES_ROUND(left, right, work, keys, keys_index)
    @DES_ROUND(right, left, work, keys, keys_index)
    @DES_ROUND(left, right, work, keys, keys_index)
    @DES_ROUND(right, left, work, keys, keys_index)
    @DES_ROUND(left, right, work, keys, keys_index)
    @DES_ROUND(right, left, work, keys, keys_index)
    @DES_ROUND(left, right, work, keys, keys_index)
    @DES_ROUND(right, left, work, keys, keys_index)
    @DES_ROUND(left, right, work, keys, keys_index)
    @FINAL_PERMUTATION(right, work, left)
    @WRITE_64BIT_DATA(to, right, left)
end

function gl_des_ecb_decrypt!(context::Gl_des_ctx, from::Array{UInt8,1}, to::Array{UInt8,1})
    gl_des_ecb_crypt!(context, from, to, true)
end

function gl_des_ecb_encrypt!(context::Gl_des_ctx, from::Array{UInt8,1}, to::Array{UInt8,1})
    gl_des_ecb_crypt!(context, from, to, false)
end

