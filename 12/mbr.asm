        ;设置栈段和栈指针
        mov eax,cs              ;使用eax，nasm编译器编译后不带0x66前缀
        mov ss,eax
        mov sp,0x7c00

        ;计算GDT所在的逻辑段地址
        mov eax,[cs:pgdt+0x7c00+0x02]   ;GDT的32位线性基地址
        xor edx,edx
        mov ebx,16
        div ebx                         ;商（段地址）在eax中，余数（段内偏移量）在edx中

        mov ds,eax                      ;ds指向GDT的段地址
        mov ebx,edx

        ;创建0#描述符，空描述符
        mov dword [ebx+0x00],0x0
        mov dword [ebx+0x04],0x0

        ;创建1#描述符，这是一个数据段，0~4GB的线性地址空间
        mov dword [ebx+0x08],0x0000ffff ;基地址为0，段界限为0xfffff
        mov dword [ebx+0x0c],0x00cf9200 ;粒度为4KB，存储器段描述符

        ;创建保护模式下初始代码段描述符
        mov dword [ebx+0x10],0x7c0001ff ;基地址为0x00007c00，512字节
        mov dword [ebx+0x14],0x00409800 ;粒度为1个字节，代码段描述符

        ;创建以上代码段的别名描述符
        mov dword [ebx+0x18],0x7c0001ff ;基地址为0x00007c00，512字节
        mov dword [ebx+0x1c],0x00409200 ;粒度为1个字节，数据段描述符

        mov dword [ebx+0x20],0x7c00fff2
        mov dword [ebx+0x24],0x00cf9600

        ;初始化描述符表寄存器GDTR
        mov dword [cs:pgdt+0x7c00],39   ;描述符表的界限

        lgdt [cs:pgdt+0x7c00]

        in al,0x92                      ;南桥芯片内的端口
        or al,0000_0010B
        out 0x92,al                     ;打开A20

        cli                             ;中断机制尚未工作，所以关中断

        mov eax,cr0
        or eax,1
        mov cr0,eax                     ;设置PE位

        ;以下进入保护模式
        jmp dword 0x0010:flush         ;16位的描述符选择子：32位偏移

        [bits 32]
    flush:
        mov eax,0x0018
        mov ds,eax

        mov eax,0x0008                  ;加载数据段（0~4GB）选择子
        mov es,eax
        mov fs,eax
        mov gs,eax

        mov eax,0x0020
        mov ss,eax
        xor esp,esp                     ;ESP <- 0

        mov dword [es:0x0b8000],0x072e0750  ;字符'P'、'.'及其显示属性
        mov dword [es:0x0b8004],0x072e074d  ;字符'M'、'.'及其显示属性
        mov dword [es:0x0b8008],0x07200720  ;两个空白字符及其显示属性
        mov dword [es:0x0b800c],0x076b076f  ;字符'o'、'k'及其显示属性

        ;开始冒泡排序
        mov ecx,pgdt-string-1               ;冒泡排序的遍历次数=串长度-1
    @@1:
        push ecx                            ;32位模式下的loop使用ecx
        xor bx,bx                           ;32位模式下，偏移量可以是16位，也可以是32位
    @@2:
        mov ax,[string+bx]
        cmp ah,al                           ;ah中存放的是源字的高字节
        jge @@3
        xchg al,ah                          ;xchg交换指令，不允许源操作做和目的操作数同时位内存单元
        mov [string+bx],ax
    @@3:
        inc bx
        loop @@2
        pop ecx
        loop @@1

        mov ecx,pgdt-string
        xor ebx,ebx                         ;偏移地址是32位
    @@4:
        mov ah,0x07
        mov al,[string+ebx]
        mov [es:0xb80a0+ebx*2],ax           ;4GB寻址
        inc ebx
        loop @@4

        hlt

    string      db 's0ke4or92xap3fv8giuzjcy5l1m7hd6bnqtw.'

    pgdt        db 0
                dd 0x00007e00               ;GDT的物理地址

    times 510-($-$$)    db 0
                        db 0x55,0xaa
