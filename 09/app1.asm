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
new_int_0x70:
        push ax
        push bx
        push cx
        push dx
        push es

    .w0:
        mov al,0x0a                     ;CMOS RAM的寄存器A
        or al,0x80                      ;bit7控制NMI中断的开关
        out 0x70,al                     ;端口0x70的最高位（bit7）是控制NMI中断的开关, 0:允许，1:阻断
        in al,0x71                      ;0x71是数据端口，上面把寄存器A的索引发给0x70端口了，所以这里读寄存器A
        test al,0x80                    ;测试第7位UIP
        jnz .w0                         ;以上代码对于更新周期结束中断来说是不必要的

        xor al,al
        or al,0x80
        out 0x70,al
        in al,0x71                      ;读RTC当前时间（秒）
        push ax

        mov al,2
        or al,0x80
        out 0x70,al
        in al,0x71                      ;读RTC当前时间（分）
        push ax

        mov al,4
        or al,0x80
        out 0x70,al
        in al,0x71                      ;读RTC当前时间（时）
        push ax

        mov al,0x0c                     ;寄存器C，且开放NMI
        out 0x70,al
        in al,0x71                      ;读一下寄存器C，使得所有中断标志复位，否则只发生一次中断
                                        ;此处不考虑闹钟和周期性中断的情况
        mov ax,0xb800
        mov es,ax

        pop ax
        call bcd_to_ascii
        mov bx,12*160 + 36*2            ;从屏幕的16行36列开始显示

        mov [es:bx],ah
        mov [es:bx+2],al

        ;mov al,':'
        mov [es:bx+4],al
        mov byte [es:bx+4],':'
        not byte [es:bx+5]              ;反转显示属性

        pop ax
        call bcd_to_ascii
        mov [es:bx+6],ah
        mov [es:bx+8],al

        ;mov al,':'
        mov [es:bx+10],al
        mov byte [es:bx+10],':'
        not byte [es:bx+11]

        pop ax
        call bcd_to_ascii
        mov [es:bx+12],ah
        mov [es:bx+14],al

        mov al,0x20                     ;中断结束命令EOI
        out 0xa0,al                     ;向8259从片发送EOI命令0x20
        out 0x20,al                     ;向8259主片发送EOI命令0x20

        pop es
        pop dx
        pop cx
        pop bx
        pop ax

        iret

;BCD码转ASCII
;输入：AL=bcd码
;输出：AX=ascii码
bcd_to_ascii:
        mov ah,al
        and al,0x0f
        add al,0x30

        shr ah,4
        and ah,0x0f
        add ah,0x30

        ret

start:
        mov ax,[stack_segment]
        mov ss,ax                       ;当处理器执行任何一条改变栈段寄存器ss的指令时，它会在下一条指令执行完期间禁止中断
        mov sp,ss_pointer               ;因此，紧跟着一条修改栈指针sp的指令
        mov ax,[data_segment]
        mov ds,ax

        mov bx,init_msg
        call put_string

        mov bx,inst_msg
        call put_string

        mov al,0x70
        mov bl,4
        mul bl                          ;计算0x70号中断在IVT(中断向量表)中的偏移
        mov bx,ax

        cli                             ;关中断，防止改动中断向量表期间发生0x70号中断

        push es
        mov ax,0x0000
        mov es,ax
        mov word [es:bx],new_int_0x70   ;偏移地址
        mov word [es:bx+2],cs           ;段地址
        pop es

        mov al,0x0b                     ;RTC寄存器B
        or al,0x80                      ;访问RTC期间，最好阻断NMI
        out 0x70,al
        mov al,0x12                     ;设置寄存器B，禁止周期性中断，开放更新结束中断, BCD码，24小时制
        out 0x71,al

        mov al,0x0c
        out 0x70,al
        in al,0x71                      ;读RTC寄存器C，复位未决的中断状态

        in al,0xa1                      ;读8259从片的IMR寄存器
        and al,0xfe                     ;清除bit 0（此位连接RTC）
        out 0xa1,al                     ;写回此寄存器

        sti                             ;开中断

        mov bx,done_msg
        call put_string

        mov bx,tips_msg
        call put_string

        mov cx,0xb800
        mov ds,cx
        mov byte [12*160 + 33*2],'@'    ;屏幕第12行，35列

.idle:
        hlt                             ;使CPU进入低功耗状态，直到用中断唤醒
        not byte [12*160 + 33*2+1]      ;反转显示属性
        jmp .idle

;显示串（0结尾）
;输入：DS:BX=串地址
put_string:
        mov cl,[bx]
        or cl,cl                        ;cl=0?
        jz .exit
        call put_char
        inc bx                          ;下一个字符
        jmp put_string

    .exit:
        ret

;显示一个字符
;输入：cl=字符ascii码
put_char:
        push ax
        push bx
        push cx
        push dx
        push ds
        push es

        ;以下取当前光标位置
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        mov dx,0x3d5
        in al,dx                    ;高8位
        mov ah,al

        mov dx,0x3d4
        mov al,0x0f
        out dx,al
        mov dx,0x3d5
        in al,dx                    ;低8位
        mov bx,ax                   ;BX=光标位置

        cmp cl,0x0d                 ;回车符？
        jnz .put_0a
        mov ax,bx
        mov bl,80
        div bl
        mul bl
        mov bx,ax
        jmp .set_cursor

.put_0a:
        cmp cl,0x0a                     ;换行符？
        jnz .put_other
        add bx,80
        jmp .roll_screen

.put_other:
        mov ax,0xb800
        mov es,ax
        shl bx,1
        mov [es:bx],cl

        ;以下将光标位置推进一个字符
        shr bx,1
        add bx,1

.roll_screen:
        cmp bx,2000                     ;光标超出屏幕? 滚屏
        jl .set_cursor

        mov ax,0xb800
        mov ds,ax
        mov es,ax
        cld
        mov si,0xa0
        mov di,0x00
        mov cx,1920
        rep movsw
        mov bx,3840                     ;清除屏幕最底一行
        mov cx,80
.cls:
        mov word [es:bx],0x0720
        add bx,2
        loop .cls

        mov bx,1920

.set_cursor:
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        mov dx,0x3d5
        mov al,bh
        out dx,al
        mov dx,0x3d4
        mov al,0x0f
        out dx,al
        mov dx,0x3d5
        mov al,bl
        out dx,al

        pop es
        pop ds
        pop dx
        pop cx
        pop bx
        pop ax

        ret

SECTION data align=16 vstart=0
    init_msg db 'Starting...',0x0d,0x0a,0
    inst_msg db 'Installing a new interrupt 70H...',0
    done_msg db 'Done.',0x0d,0x0a,0
    tips_msg db 'Clock is now working,',0

SECTION stack align=16 vstart=0

        resb 256

ss_pointer:

SECTION program_trail
program_end: