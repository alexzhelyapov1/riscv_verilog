.section .text
.global _start

_start:
    addi x1, x0, 1
    add x1, x1, x1
    add x1, x1, x1
    add x1, x1, x1
    sub x1, x1, x1
    sd x1, 0x10(x0)
    addi x1, x0, 5
    ld x1, 0x10(x0)
    beq x1, x1, end
    addi x5, x0, 500
    nop
    nop
    nop
    nop
    nop
    nop
    nop
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
    sret
