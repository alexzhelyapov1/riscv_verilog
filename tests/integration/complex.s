.section .text
.global _start

_start:
    addi x12, x0, 1
    add x1, x0, x12
    addi x5, x0, 10
    addi x6, x0, 5
    sub  x5, x5, x6
loop:
    addi x1, x1, 1
    sd x1, 0x10(x0)
    ld x1, 0x10(x0)
    beq x5, x1, endloop
    jal x10, loop
endloop:
    jal x4, poop
    addi x1, x1, 500
poop:
    addi x1, x0, 0
    slti x1, x5, 10
    addi x15, x0, 1
    beq x1, x15, end
    addi x1, x1, 600
end:
    addi x8, x0, 0
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
