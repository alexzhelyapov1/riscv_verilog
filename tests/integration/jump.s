.section .text
.global _start

_start:
    addi x1, x0, 1
loop:
    addi x1, x1, 1
    jal x4, loop
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