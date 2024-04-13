.equ SYS_IOCTL, 29

.equ SYS_FCNTL, 25
.equ SYS_READ, 63

.equ SYS_WRITE, 64

.equ SYS_EXIT, 93

.equ SYS_CLOCK_GETTIME, 113

.equ SYS_MMAP, 222

.equ PROT_READ,    1
.equ PROT_WRITE,   2
.equ MAP_PRIVATE,  2
.equ MAP_ANONYMOUS,32

.equ SYS_MUNMAP, 215

.equ GET_WINDOW_SIZE, 0x5413

.equ TCGETS, 0x5401
.equ TCSETS, 0x5402


.equ NO_BLOCK, 2048

.equ STDOUT, 1
.equ STDIN, 0

.equ CLOCK_MONOTONIC, 1

.data
        printData:      .ascii "\nO.#"

        inputChar:      .quad 0

        fcntlFlags:     .quad 0

        clearCommand:   .ascii "\033[H\033[2J\033[3J"

        cursorOff:      .asciz "\x1b[?25l"
        cursorOn:       .asciz "\x1b[?25h"

terminalSize:
        terminalHeight: .short 0
        terminalWidth:  .short 0

termiosConfig:
        c_iflag:        .word 0
        c_oflag:        .word 0
        c_cflag:        .word 0
        c_lflag:        .word 0
        c_cc:           .space 32
        c_ispeed:       .word 0
        c_ospeed:       .word 0

timeInfo:
        tv_sec:         .quad 0
        tv_usec:        .quad 0


.text
.global _start

//x0-x8 reserved

//x9 current window width
//x10 current window height
//x11 total fields

//x12 old cuurent window width
//x13 old cuurent window height

//x14 curerent printed char

//x15 clock input start info sec
//x16 clock input start info usec

//x17 current clock info sec
//x18 current clock info usec

//x19 char input

//x20 mmap address game data
//x21 mmap len

// x0: x8 x0 x1 x2 x3 x4 x5
_start:
        mov x25, x0

        mov x8, SYS_IOCTL               //syscall number for ioctl
        mov x0, STDOUT                  //file descriptor of stdout
        mov x1, GET_WINDOW_SIZE //command number for get size
        ldr x2, =terminalSize   //poiner to struct for teminal size
        svc 0                                   //syscall

        ldr x0, =terminalWidth
        ldrb w0, [x0]
        uxtw x9, w0

        ldr x0, =terminalHeight
        ldrb w0, [x0]
        uxtw x10, w0

        mul x11, x9, x10

        mov x12, 0
        mov x13, 0


        mov x8, SYS_MMAP
        mov x0, 0
        mov x1, x11
        mov x2, #(PROT_READ | PROT_WRITE)
        mov x3, #(MAP_PRIVATE | MAP_ANONYMOUS)
        mov x4, #-1
        mov x5, #0

        svc 0

        cmp x0, 0
        b.le _error_mmap

        mov x20, x0
        mov x21, x11

        mov x0, 0

        mov x8, SYS_IOCTL               //syscall number for ioctl
        mov x0, STDIN                   //file descriptor for stdin
        mov x1, TCGETS                  //command number for TCGETS
        ldr x2, =termiosConfig  //pointer to the termios config

        svc 0                                   //syscall


        ldr x0, =c_lflag                //load adress of the c_lflag of the termios config
        ldr w1, [x0]                    //load the value into w0
        bic w1, w1, #2                  //clear bit 2 for non canonical
        bic w1, w1, #8                  //clear bit 4 to disable echo
        str w1, [x0]                    //load modifyed value into c_lflag of the termios config structure

        mov x8, SYS_IOCTL               //syscall number for ioctl
        mov x0, #1                              //file descriptor for stdin
        mov x1, TCSETS                  //command for TCSETS
        ldr x2, =termiosConfig  //pointer to termios config structure

        svc #0                                  //syscall


        mov x8, SYS_FCNTL
        mov x0, #0
        mov x1, #4
        mov x2, NO_BLOCK

        //svc #0


        mov x8, SYS_WRITE
        mov x0, #1
        ldr x1, =cursorOff
        mov x2, #6

        svc #0

_loop:
        mov x8, SYS_WRITE
        mov x0, STDOUT
        ldr x1, =clearCommand
        mov x2, #11

        svc #0

        mov x8, SYS_MMAP
        mov x0, 0
        mov x1, x11
        mov x2, #(PROT_READ | PROT_WRITE)
        mov x3, #(MAP_PRIVATE | MAP_ANONYMOUS)
        mov x4, #-1
        mov x5, #0

        svc 0

        mov x30, x0

        mov x29, 0

        mov w28, 128
        strb w28, [x20, 5]

        _writeDSPBufferLoop:
                ldrb w28, [x20, x29]

                mov w27, 0
                cmp w28, w27
                b.ne _notEmpty

                mov w28, '.'
                strb w28, [x30, x29]
                b _nextIteration

                _notEmpty:

                mov w27, 128
                cmp w28, w27
                b.ne _notFruit

                mov w28, 'O'
                strb w28, [x30, x29]
                b _nextIteration

                _notFruit:

                _nextIteration:

                add x29, x29, 1
                cmp x29, x11
                b.ne _writeDSPBufferLoop




        mov x8, SYS_WRITE
        mov x0, STDOUT
        mov x1, x30
        mov x2, x11

        svc #0


        mov x8, SYS_MUNMAP
        mov x0, x30
        mov x1, x11


        mov x8, SYS_CLOCK_GETTIME
        mov x0, CLOCK_MONOTONIC
        ldr x1, =timeInfo

        svc #0

        ldr x13, =tv_sec
        ldr x13, [x13]

        ldr x14, =tv_usec
        ldr x14, [x14]

        _inputWaitLoop:

                mov x8, SYS_READ
                mov x0, STDIN
                ldr x1, =inputChar
                mov x2, #1

                svc #0

                cmp x0, #-11
                b.eq _noInput

                ldr x30, =inputChar
                ldrb w0, [x30]
                uxtw x30, w0

                cmp x30, #'q'
                b.eq _exit

        _noInput:

                mov x8, SYS_CLOCK_GETTIME
                mov x0, CLOCK_MONOTONIC
                ldr x1, =timeInfo

                svc #0

                ldr x15, =tv_sec
                ldr x15, [x15]

                ldr x16, =tv_usec
                ldr x16, [x16]

                cmp x13, x15

                b.eq _inputWaitLoop

        b _loop

_exit:

        mov x8, SYS_MUNMAP
        mov x0, x20
        mov x1, x21

        svc #0

        mov x8, SYS_WRITE
        mov x0, STDOUT
        ldr x1, =clearCommand
        mov x2, #11

        svc #0

        mov x8, SYS_FCNTL
        mov x0, #0
        mov x1, #4
        mov x2, #2

        svc #0


        ldr x0, =c_lflag                //load c_lflag of termios structure
        ldr w1, [x0]                    //load value of c_lflag
        orr w1, w1, #2                  //set bit 2 for canonical mode
        orr w1, w1, #8                  //set bit 4 to enable echo
        str w1, [x0]                    //store modifyed value into c_lflag of the termios structure

        mov x8, SYS_IOCTL               //syscall number for ioctl
        mov x0, #1                              //file descriptor for stdin
        mov x1, TCSETS                  //command for TCSETS
        ldr x2, =termiosConfig  //pointer to termios config

        svc #0                          //syscall

        mov x8, SYS_WRITE
        mov x0, 1
        ldr x1, =cursorOn
        mov x2, 6

        svc 0

        mov x8, SYS_WRITE
        mov x0, 1
        ldr x1, =clearCommand
        mov x2, 11

        //exit with code in x0
        mov x8, SYS_EXIT
        mov x0, 42
        svc 0

        mov x3, 1

        b .

_error_mmap:
        mov x8, SYS_EXIT
        mov x0, -1

        svc 0


/*
load .data var into register

ldr x0, =terminalWidth
ldr x0, [x0]

load .data var into register


ldr x0, =terminalWidth
mov x1, 42
str x1, [x0]

*/

/*

cell = 8 bits

FSKPS000

F = fruit

S = is snake

PS = snake direction

H = head

*/

/*

...........................................
...........................................
...........................................
.........O.................................
..................................O........
...........................................
......................#####................
..........................#................
..........................#................
...............############................
...........................................
...........................................
...........................................
...........................................
...............................O...........
...........................................
*/