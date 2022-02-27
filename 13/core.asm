        core_code_seg_sel   equ 0x38        ;内核代码段选择子
        core_data_seg_sel   equ 0x30        ;内核数据段选择子
        sys_routing_seg_sel equ 0x28        ;系统公共例程代码段的选择子
        video_ram_seg_sel   equ 0x20        ;视频显示缓冲区的段选择子
        core_stack_seg_sel  equ 0x18        ;内核堆栈段选择子
        mem_0_4_gb_seg_sel  equ 0x08        ;整个0-4GB内存的段的选择子

        ;以下是系统核心的头部，用于加载内核
        core_length         dd  core_end    ;核心程序总长度#00

        sys_routing_seg     dd section.sys_routing.start    ;系统公用例程段位置#04

        core_data_seg       dd section.core_data.start      ;核心数据段位置#08

        core_code_seg       dd section.core_code.start      ;核心代码段位置#0c

        core_entry          dd start                        ;核心代码段入口点#10
                            dw core_code_seg_sel

        [bits 32]

SECTION sys_routing vstart=0        ;系统公共例程代码段

        ;字符串显示例程
put_string:                         ;显示0终止的字符串并移动光标
                                    ;输入：DS:EBX=串地址
        push ecx
    .getc:
        mov cl,[ebx]
        or cl,cl
        jz .exit
        call put_char
        inc ebx
        jmp .getc

    .exit:
        pop ecx
        retf                        ;段间返回

    put_char:                       ;在当前光标处显示一个字符，并推进光标
                                    ;仅用于段内调用
                                    ;输入：CL=字符ASCII码
        pushad                      ;本指令将EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI
                                    ;这8个32位通用寄存器依次压入堆栈,其中SP的值是在此条件指令未执行之前的值.
                                    ;压入堆栈之后,ESP-32–>ESP.
        ;以下取当前光标位置
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        inc dx
        in al,dx
        mov ah,al

        dec dx
        mov al,0x0f
        out dx,al
        inc dx
        in al,dx
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
        cmp cl,0x0a                 ;换行符?
        jnz .put_other
        add bx,80
        jmp .roll_screen

    .put_other:
        push es
        mov eax,video_ram_seg_sel   ;0xb8000段的选择子
        mov es,eax
        shl bx,1
        mov [es:bx],cl
        pop es

        ;以下将光标位置推进一个字符
        shr bx,1
        inc bx

    .roll_screen:
        cmp bx,2000                 ;光标超出屏幕？滚屏
        jl .set_cursor

        push ds
        push es
        mov eax,video_ram_seg_sel
        mov ds,eax
        mov es,eax
        cld
        mov esi,0xa0                ;小心！32位模式下movsb/w/d
        mov edi,0x00
        mov ecx,1920
        rep movsd
        mov bx,3840                 ;清除屏幕最底一行
        mov ecx,80                  ;32位程序应该使用ECX
    .cls:
        mov word [es:bx],0x0720
        add bx,2
        loop .cls

        pop es
        pop ds

        mov bx,1920

    .set_cursor:
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        inc dx
        mov al,bh
        out dx,al
        dec dx
        mov al,0x0f
        out dx,al
        inc dx
        mov al,bl
        out dx,al

        popad
        ret

;从硬盘读取一个逻辑扇区
;EAX=逻辑扇区号
;DS:EBX=目标缓冲区地址
;返回：EBX=EBX+512
read_hard_disk_0:
        push eax
        push ecx
        push edx

        push eax

        mov dx,0x1f2
        mov al,1
        out dx,al               ;读取的扇区数

        inc dx                  ;0x1f3
        pop eax
        out dx,al               ;LBA地址7~0

        inc dx
        mov cl,8
        shr eax,cl
        out dx,al               ;LBA地址15~8

        inc dx
        shr eax,cl
        out dx,al               ;LBA地址23~16

        inc dx
        shr eax,cl
        or al,0xe0              ;第一硬盘 LBA地址27~24
        out dx,al

        inc dx                  ;0x1f7
        mov al,0x20             ;读命令
        out dx,al

    .waits:
        in al,dx
        and al,0x88
        cmp al,0x08
        jnz .waits

        mov ecx,256
        mov dx,0x1f0
    .readw:
        in ax,dx
        mov [ebx],ax
        add ebx,2
        loop .readw

        pop edx
        pop ecx
        pop eax

        retf                    ;段间返回

;在当前光标处以十六进制形式显示一个双字并推进光标
;输入：EDX=要转换并显示的数字
;输出：无
put_hex_dword:
        pushad
        push ds

        mov ax,core_data_seg_sel    ;切换到核心数据段
        mov ds,ax

        mov ebx,bin_hex             ;指向核心数据段内的转换表
        mov ecx,8
    .xlt:
        rol edx,4
        mov eax,edx
        and eax,0x0000000f
        xlat                        ;查表指令，DS:EBX+AL -> AL

        push ecx
        mov cl,al
        call put_char
        pop ecx

        loop .xlt

        pop ds
        popad
        retf

;分配内存
;输入：ECX=希望分配的字节数
;输出：ECX=起始线性地址
allocate_memory:
        push ds
        push eax
        push ebx

        mov eax,core_data_seg_sel
        mov ds,eax

        mov eax,[ram_alloc]
        add eax,ecx                 ;下一次分配时的起始地址

        ;这里应当由检测可用内存数量的指令

        mov ecx,[ram_alloc]         ;返回分配的起始地址

        mov ebx,eax
        and ebx,0xfffffffc
        add ebx,4                   ;强制对齐
        test eax,0x00000003         ;下次分配的起始地址最好是4字节对齐
        cmovnz  eax,ebx             ;如果没有对齐，则强制对齐，条件传送指令
        mov [ram_alloc],eax

        pop ebx
        pop eax
        pop ds

        retf

;在GDT内安装一个新的描述符
;输入：EDX:EAX=描述符
;输出：CX=描述符的选择子
set_up_gdt_descriptor:
        push eax
        push ebx
        push edx

        push ds
        push es

        mov ebx,core_data_seg_sel
        mov ds,ebx

        sgdt [pgdt]                     ;以便开始处理GDT

        mov ebx,mem_0_4_gb_seg_sel
        mov es,ebx

        movzx ebx,word [pgdt]           ;GDT界限，movzx是无符号扩展并传送指令
        inc bx                          ;GDT总字节数，也是下一个描述符偏移
        add ebx,[pgdt+2]                ;下一个描述符的线性地址

        mov [es:ebx],eax
        mov [es:ebx+4],edx

        add word [pgdt],8               ;增加一个描述符的大小

        lgdt [pgdt]                     ;对GDT的更改生效

        mov ax,[pgdt]                   ;得到GDT界限值
        xor dx,dx
        mov bx,8
        div bx                          ;除以8，去掉余数
        mov cx,ax
        shl cx,3                        ;将索引号移到正确位置

        pop es
        pop ds

        pop edx
        pop ebx
        pop eax

        retf

;构造存储器和系统的段描述符
;输入：EAX=线性基地址
;       EBX=段界限
;       ECX=属性，各属性位都在原始位置，无关的位清零
;返回：EDX:EAX=描述符
make_seg_descriptor:
        mov edx,eax
        shl eax,16
        or ax,bx                    ;描述符前32位（EAX）构造完毕

        and edx,0xffff0000          ;清除基地址中无关的位
        rol edx,8
        bswap edx                   ;装配基址的31~24和23~16 (80486+)

        xor bx,bx
        or edx,ebx                  ;装配段界限的高4位

        or edx,ecx                  ;装配属性

        retf