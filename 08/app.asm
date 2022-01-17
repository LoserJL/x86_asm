    ;用户程序

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
               dd section.code_1.start  ;段地址[0x06]

    realloc_tbl_len dw (header_end-code_1_segment)/4    ;段重定位表项数[0x0a]

    ;段重定位表
    code_1_segment dd section.code_1.start ;[0x0c]
    code_2_segment dd section.code_2.start ;[0x10]
    data_1_segment dd section.data_1.start ;[0x14]
    data_2_segment dd section.data_2.start ;[0x18]
    stack_segment dd section.stack.start ;[0x1c]

    header_end:

SECTION code_1 align=16 vstart=0
;显示字符串
;输入：DS:BX=字符串地址
put_string:
        mov cl,[bx]
        or cl,cl            ;判断cl是否为0，为0则字符串结束
        jz .exit
        call put_char
        inc bx
        jmp put_string

    .exit:
        ret

;显示一个字符
;输入：cl=字符ascii
put_char:
        push ax
        push bx
        push cx
        push dx
        push ds
        push es

        ;以下取当前光标位置
        mov dx,0x3d4        ;显卡的索引寄存器端口号0x3d4，向它写入要访问的寄存器的地址
        mov al,0x0e         ;0x0e是光标位置的高8位
        out dx,al
        mov dx,0x3d5        ;0x3d5是显卡的数据端口
        in al,dx            ;高8位
        mov ah,al

        mov dx,0x3d4
        mov al,0x0f         ;0x0f是光标位置的低8位
        out dx,al
        mov dx,0x3d5
        in al,dx            ;低8位
        mov bx,ax           ;BX代表光标位置的16位数

        cmp cl,0x0d         ;回车符？
        jnz .put_0a
        ;mov ax,bx
        mov bl,80           ;每行80个字符
        div bl              ;ax除以80在al中得到的商是行号
        mul bl              ;行号再乘以80会在ax中得到行首的光标位置
        mov bx,ax           ;BX代表光标位置
        jmp .set_cursor

    .put_0a:
        cmp cl,0x0a         ;换行符
        jnz .put_other
        add bx,80
        jmp .roll_screen

    .put_other:
        mov ax,0xb800
        mov es,ax
        shl bx,1            ;显存中，一个显示的字符对应两个字节，所以光标位置乘以2就是字符在显存中的偏移地址
        mov [es:bx],cl

        ;将光标位置推进一个字符
        shr bx,1
        add bx,1

    .roll_screen:
        cmp bx,2000         ;光标超出屏幕?
        jl .set_cursor

        mov ax,0xb800
        mov ds,ax
        mov es,ax
        cld                 ;DF=0, 向高地址增加
        mov si,0xa0         ;ds:si
        mov di,0x00         ;es:di
        mov cx,1920
        rep movsw           ;执行1920次，将0xb800:0xa0处移到0xb800:0x00处
        mov bx,3840         ;显存中最后一行行首的偏移地址
        mov cx,80
    .cls:
        mov word[es:bx],0x0720    ;0x0720黑底白字的空白字符
        add bx,2
        loop .cls

        mov bx,1920

    .set_cursor:
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        mov dx,0x3d5
        mov al,bh           ;光标高8位
        out dx,al
        mov dx,0x3d4
        mov al,0x0f
        out dx,al
        mov dx,0x3d5
        mov al,bl           ;光标低8位
        out dx,al

        pop es
        pop ds
        pop dx
        pop cx
        pop bx
        pop ax

        ret

start:
        ;初始执行时，DS和ES指向用户程序头部
        mov ax,[stack_segment]          ;设置到用户程序自己的堆栈
        mov ss,ax
        mov sp,stack_end

        mov ax,[data_1_segment]         ;设置到用户程序自己的数据段
        mov ds,ax

        mov bx,msg0
        call put_string                 ;显示第一段信息

        push word [es:code_2_segment]
        mov ax,begin
        push ax                         ;可以直接push begin, 80386+

        retf                            ;转移到代码段2执行

    continue:
        mov ax,[es:data_2_segment]      ;段寄存器DS切换到数据段2
        mov ds,ax

        mov bx,msg1
        call put_string

        jmp $

SECTION code_2 align=16 vstart=0

    begin:
        push word [es:code_1_segment]
        mov ax,continue
        push ax

        retf                            ;转移到代码段1接着执行

SECTION data_1 align=16 vstart=0

    msg0 db '  This is NASM - the famous Netwide Assembler. '
         db 'Back ar SourceForge and in intensive development! '
         db 'Get the current versions from http://www.nasm.us/.'
         db 0x0d,0x0a,0x0d,0x0a
         db '  Example code for calculate 1+2+...+100:',0x0d,0x0a,0x0d,0x0a
         db '     xor dx,dx',0x0d,0x0a
         db '     xor ax,ax',0x0d,0x0a
         db '     xor cx,cx',0x0d,0x0a
         db '  @@:',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     add ax,cx',0x0d,0x0a
         db '     adc dx,0',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     cmp cx,1000',0x0d,0x0a
         db '     jle @@',0x0d,0x0a
         db '     ... ...(Some other codes)',0x0d,0x0a,0x0d,0x0a
         db 0

SECTION data_2 align=16 vstart=0

    msg1 db '  The above contents is written by CoolLoser. '
         db '2022-01-17'
         db 0

SECTION stack align=16 vstart=0

        resb 256

stack_end:

SECTION trail align=16
program_end: