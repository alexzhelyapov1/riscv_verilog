.section .text
.global _start

_start:
    addi x1, x0, 1
    sd x1, 0x10(x0)
    ld x2, 0x10(x0)
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