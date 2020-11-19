
macro READ_64BIT_DATA(data, left, right)
    quote
        ldata = $(esc(data))
        $(esc(left)) = (ldata[1] << 24) | (ldata[2] << 16) | (ldata[3] << 8) | ldata[4]
        $(esc(right)) = (ldata[5] << 24) | (ldata[6] << 16) | (ldata[7] << 8) | ldata[8]
    end
end

macro DO_PERMUTATION(a, temp, b, offset, mask)
    quote
        $(esc(temp)) = ( ( $(esc(a)) >> $(esc(offset)) ) ⊻ $(esc(b)) ) & $(esc(mask))
        $(esc(b)) ⊻= $(esc(temp))
        $(esc(a)) ⊻= $(esc(temp)) << $(esc(offset))
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
    right = ((rightkey_swap[1+((right >> 1) & 0xf)] << 3)
    | (rightkey_swap[1+((right >> 9) & 0xf)] << 2)
    | (rightkey_swap[1+((right >> 17) & 0xf)] << 1)
    | (rightkey_swap[1+((right >> 25) & 0xf)])
    | (rightkey_swap[1+((right >> 4) & 0xf)] << 7)
    | (rightkey_swap[1+((right >> 12) & 0xf)] << 6)
    | (rightkey_swap[1+((right >> 20) & 0xf)] << 5)
    | (rightkey_swap[1+((right >> 28) & 0xf)] << 4))
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

function gl_des_ecb_crypt(context::Gl_des_ctx, from::Array{UInt8,1}, to::Array{UInt8,1}, mode::Bool)

    
    keys = mode ? context.decrypt_subkeys : context.encrypt_subkeys


end

