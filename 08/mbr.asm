    app_lba_start equ 100   ;声明常数，用户程序起始逻辑扇区号
                            ;常数的声明，不占用汇编地址

SECTION mbr align=16 vstart=0x7c00
        ;设置堆栈段和栈指针
        mov ax,0
        mov ss,ax
        mov sp,ax

        mov ax,[cs:phy_base]    ;计算用于加载用户程序的逻辑段地址
        mov dx,[cs:phy_base+2]
        mov bx,16
        div bx
        mov ds,ax           ;ds和es指向该段
        mov es,ax

        ;以下读取程序的起始部分
        xor di,di
        mov si,app_lba_start
        xor bx,bx               ;读取到DS:0000处
        call read_hard_disk_0

        ;以下判断整个程序有多大
        mov dx,[2]
        mov ax,[0]
        mov bx,512
        div bx
        cmp dx,0
        jnz @1                  ;dx-0不为0，说明未除尽，因此结果比实际扇区数少1
        dec ax                  ;除尽了，由于已经读了一个扇区了，因此这里要减1
    @1:
        cmp ax,0                ;判断一下程序是否仅仅只有一个扇区，这个扇区也被读取过了
        jz direct

        ;读取剩余的扇区数
        push ds                 ;以下要用到ds

        mov cx,ax               ;剩余扇区数，用作循环次数
    @2:
        mov ax,ds               ;此时ds是用户程序的逻辑段地址
        add ax,0x20             ;得到下一个以512字节为边界的段地址
        mov ds,ax

        xor bx,bx               ;由于ds调整为下一个512字节的段地址了，所以每次读的偏移地址都为0
        inc si                  ;下一个逻辑扇区号
        call read_hard_disk_0
        loop @2

        pop ds                  ;恢复数据段基址到用户程序头部段

    ;计算入口点代码段地址
    direct:
        mov dx,[0x08]
        mov ax,[0x06]
        call calc_segment_base
        mov [0x06],ax           ;回填修正后的入口点代码段地址

        ;开始处理段重定位表
        mov cx,[0x0a]           ;段重定位表项数
        mov bx,0x0c             ;重定位表首地址
    realloc:
        mov dx,[bx+0x02]        ;32为地址的高16位
        mov ax,[bx]
        call calc_segment_base
        mov [bx],ax             ;回填段的基址
        add bx,4                ;下一个重定位表项（每项4字节）
        loop realloc

        jmp far [0x04]          ;转移到用户程序

;从硬盘读取一个逻辑扇区
;输入：DI:SI=起始逻辑扇区号
;     DS:BX=目标缓冲区地址
read_hard_disk_0:
        push ax
        push bx
        push cx
        push dx

        mov dx,0x1f2     ;0x1f2是设置读取扇区数的8位端口，因此每次最大可读256个扇区
        mov al,1         ;读取一个扇区数
        out dx,al

        inc dx           ;dx自加1之后是0x1f3端口，0x1f3~0x1f6为28位起始LBA扇区号
                        ;0x1f3为7~0bit, 0x1f4为15~8bit, 0x1f5为23~16bit, 0x1f6为27~24bit
        mov ax,si
        out dx,al

        inc dx
        mov al,ah
        out dx,al

        inc dx
        mov ax,di
        out dx,al

        inc dx
        mov al,0xe0     ;0x1f6 3~0bit用于存放起始逻辑扇区的27~24bit, 4bit为0是主盘，为1是从盘，7~5bit为111b, 表示LBA模式
        or al,ah
        out dx,al

        inc dx          ;0x1f7端口写入0x20，请求读硬盘
        mov al,0x20
        out dx,al

    .waits:
        in al,dx        ;0x1f7也是状态端口，第7位为1表示忙，忙完之后第7位清零，同时将第3位置1
        and al,0x88     ;第7和第3bit
        cmp al,0x08     ;cmp指令是第一个操作数减去第二个操作数，但不改变其原值，只影响标志位
        jnz .waits      ;jnz和jne一样，结果不为0或者不相等跳转

        mov cx,256      ;总共要读取的字数
        mov dx,0x1f0    ;0x1f0是一个16位端口，从这个端口读取数据
    .readw:
        in ax,dx
        mov [bx],ax
        add bx,2
        loop .readw
    
    pop dx
    pop cx
    pop bx
    pop ax

    ret

;计算16位段地址
;输入：DX:AX=32位物理地址
;返回：AX=16位段基地址
calc_segment_base:
        push dx

        ;dx:ax + 0x10000
        add ax,[cs:phy_base]
        adc dx,[cs:phy_base+0x02]       ;adc带进位的加法，把CF位也加进来，因为上一步运算可能有进位
        shr ax,4
        ror dx,4                        ;循环右移，每次移出的bit既送到CF，也送到左边空出的位
        and dx,0xf000                   ;只留下上一步从低位移过来的4bits
        or ax,dx

        pop dx

        ret

        phy_base dd 0x10000             ;用户程序被加载的物理起始地址

times 510-($-$$) db 0
                 db 0x55,0xaa