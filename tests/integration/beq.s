.section .text
.global _start

_start:
    addi x1, x0, 1
    addi x2, x0, 5
    addi x3, x0, 5
loop:
    addi x1, x1, 1
    beq x2, x3, loop
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