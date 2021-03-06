;段描述符格式：
; 31            24 23  22   21   20  19          16 15 14  13 12 11    8 7             0
;|---------------|---|-----|---|-----|------------|---|-----|---|-------|--------------|
;| 段基地址 31~24 | G | D/B | L | AVL | 段界限 19~16 | P | DPL | S | TYPE | 段基地址 23~16 |
;|-------------------------------------------------------------------------------------|
;
; 31                                       16 15                                       0
;|-------------------------------------------|-----------------------------------------|
;|               段基地址 15~0                 |            段界限 15~0                  |
;|-------------------------------------------------------------------------------------|
;
; 解释如下：
; G是粒度(Granularity)位，用于解释段界限的含义，G=0，段界限以字节为单位，此时段的扩展范围是从1字节到1M字节，以为段界限是20位的，
;    G=1，段界限以4KB为单位，段的扩展范围从4KB到4GB
; S用于指定描述符的类型，S=0，表示系统段，S=1，表示代码段或数据段
; DPL表示描述符的特权级别，0，1，2，3，其中0位最高特权级，3为最底特权级，刚进入保护模式为最高级别，通常是操作系统代码
; P是段存在位
; D/B是“默认的操作数大小”或者“默认的栈指针大小”，又或者“上部边界”标志，对于代码段，称作D位，用于指示指令中默认的偏移地址和操作数尺寸，
;   D=0表示指令中的偏移地址或者操作数是16位的，D=1指示32位的偏移地址或者操作数
;   对于栈段，改位叫做B位，用于在进行隐式的栈操作是，是使用SP寄存器还是ESP寄存器。B=0，使用SP，B=1，使用ESP，
;   同时，B位的值也决定了栈的上部边界，B=0，栈的上部边界（SP的最大值）位0xFFFF，B=1，ESP最大值位0xFFFFFFFF，一般来说B=1，因为16位保护模式基本不用了
; L是64位代码段标志，保留此位给64位处理器使用，目前设为0即可
; TYPE字段共4位，用于指示描述符的子类型，或者说是类别，对于数据段，这4位为X，E，W，A，对于代码段，这4位为X，C，R，A
;   X表示是否可执行，因此对于代码段X=1，对于数据段，X=0，E指示段的扩展方向，E=0，向上扩展，E=1是向下扩展，所以栈段E=1
;   W指示段的读写属性，
;   C指示段是否为特权级依从的，C=0表示非依从的代码段，这样的代码段可以从它特权级相同的代码段调用，或者通过门调用，C=1表示允许从低特权级的程序转移到该段执行
;   R位指示代码段是否允许读出，处理器执行指令不受R位限制
;   A是已访问位，用于指示它所指向的段最近是否被访问过，在创建描述符时，应该清0，通过监视改位，可以把不经常使用的段退避到硬盘，实现虚拟内存管理
;   AVL是软件可以使用的位，通常由操作系统来用，处理器并不使用

;段选择子格式：
; 15                         3   2   1    0
;|---------------------------|------|-----|
;|      描述符索引           |  TI  | RPL |
;|----------------------------------------|
; 描述符索引是描述符表中的索引号，TI=0，在GDT中，TI=1，在LDT中，RPL是请求特权级

    ;设置栈段和栈指针
    mov ax,cs    ;从ROM-BIOS转过来，cs应该为0x0000
    mov ss,ax
    mov sp,0x7c00

    ;计算GDT所在的逻辑段地址
    mov ax,[cs:gdt_base+0x7c00]    ;低16位
    mov dx,[cs:gdt_base+0x7c00+2]  ;高16位
    mov bx,16
    div bx
    mov ds,ax                       ;令DS指向GDT段以进行操作
    mov bx,dx                       ;GDT段内起始偏移地址

    ;创建0#描述符，空描述符
    mov dword [bx+0x00],0x00
    mov dword [bx+0x04],0x00

    ;创建1#描述符，保护模式下的代码段描述符
    mov dword [bx+0x08],0x7c0001ff
    mov dword [bx+0x0c],0x00409800

    ;创建2#描述符，保护模式下的数据段描述符（文本模式下得显示缓冲区）
    mov dword [bx+0x10],0x8000ffff
    mov dword [bx+0x14],0x0040920b

    ;创建3#描述符，保护模式下的栈段描述符
    mov dword [bx+0x18],0x00007a00
    mov dword [bx+0x1c],0x00409600

    ;初始化描述符表寄存器GDTR
    mov word [cs:gdt_size+0x7c00],31    ;描述符表的界限（总字节数减1）

    lgdt [cs:gdt_size+0x7c00]           ;lgdt的操作数是一个48位（6字节）的内存区域，16位模式下，是16位的，32位模式下是32位的

    in al,0x92                          ;南桥芯片内的端口
    or al,0000_0010B
    out 0x92,al                         ;打开A20

    cli                                 ;保护模式下中断机制尚未建立，所以禁止中断

    mov eax,cr0
    or eax,1
    mov cr0,eax                         ;设置PE位，进入保护模式

    ;以下进入保护模式
    jmp dword 0x0008:flush              ;16位的描述符选择子(代码段描述符索引)：32位偏移
										;清流水线(实模式下已进入流水线的指令)并串行化处理器(实模式下乱序执行的中间结果)
										;处理器遇到jmp和call一般会清空流水线并串行化执行
										;保护模式下，不能使用mov指令修改cs段寄存器

    [bits 32]                           ;告诉编译器，以下使用32位模式编译

flush:
    mov cx,00000000000_10_000B          ;加载数据段选择子（0x10），描述符索引=2，TI=0，RPL=00b
    mov ds,cx

    ;以下在屏幕上显示“Protect mode OK.”
    mov byte [0x00],'P'
    mov byte [0x02],'r'
    mov byte [0x04],'o'
    mov byte [0x06],'t'
    mov byte [0x08],'e'
    mov byte [0x0a],'c'
    mov byte [0x0c],'t'
    mov byte [0x0e],' '
    mov byte [0x10],'m'
    mov byte [0x12],'o'
    mov byte [0x14],'d'
    mov byte [0x16],'e'
    mov byte [0x18],' '
    mov byte [0x1a],'O'
    mov byte [0x1c],'K'

    ;以下用简单的示例来帮助阐述32位保护模式下的堆栈操作
    mov cx,00000000000_11_000B      ;加载堆栈段选择子
    mov ss,cx
    mov esp,0x7c00

    mov ebp,esp                     ;保存堆栈指针
    push byte '.'                   ;压入立即数（字节）

    sub esp,4
    cmp ebp,esp                     ;判断压入立即数时，ESP是否减4
    jnz ghalt
    pop eax
    mov [0x1e],al                   ;显示句点

ghalt:
    hlt                             ;中断被禁止，这里不会被唤醒

    gdt_size    dw 0
    gdt_base    dd 0x00007e00       ;GDT的物理地址

    times 510-($-$$) db 0
                     db 0x55,0xaa
