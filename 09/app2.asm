    ;用户程序
    ;使用上一节的mbr程序加载

;用户程序头部结构:
;--------------------------------------------------------------------------------------------------------
;| 用户程序总长度 | 入口点:偏移地址 | 入口点所在代码段的汇编地址 | 段重定位表项数 | 段重定位表格 | 用户程序指令和数据... |
;--------------------------------------------------------------------------------------------------------
;|0x00          |0x04           |0x06                   |0x0A          |0x0c        |....                |
;--------------------------------------------------------------------------------------------------------

SECTION header vstart=0             ;用户程序头部段
    program_length dd program_end   ;用户程序总长度[0x00]

    ;用户程序入口点
    code_entry dw start                 ;偏移地址[0x04]
               dd section.code.start  ;段地址[0x06]

    realloc_tbl_len dw (header_end-realloc_begin)/4    ;段重定位表项数[0x0a]

    realloc_begin:
    ;段重定位表
    code_segment dd section.code.start ;[0x0c]
    data_segment dd section.data.start ;[0x10]
    stack_segment dd section.stack.start ;[0x14]

    header_end:

SECTION code align=16 vstart=0
start:
        mov ax,[stack_segment]
        mov ss,ax
        mov sp,ss_pointer
        mov ax,[data_segment]
        mov ds,ax

        mov cx,msg_end-message      ;循环次数
        mov bx,message

    .putc:
        mov ah,0x0e
        mov al,[bx]
        int 0x10                    ;BIOS中断0x10的0x0e号功能，用于在屏幕上的光标位置处写一个字符，并推进光标位置
        inc bx
        loop .putc

    .reps:
        mov ah,0x00
        int 0x16                    ;BIOS中断0x16的0x00号功能，用于从键盘读字符，中断返回后，AL中位读取的字符ascii码

        mov ah,0x0e
        mov bl,0x07
        int 0x10

        jmp .reps

SECTION data align=16 vstart=0
    message db 'Hello, friend!',0x0d,0x0a
            db 'This simple procedure used to demonstrate '
            db 'the BIOS interrupt.',0x0d,0x0a
            db 'Please press the keys on the keyboard ->'
    msg_end:

SECTION stack align=16 vstart=0

        resb 256
ss_pointer:

SECTION program_trail
program_end: