    jmp near start

message db '1+2+3+...+100='

start:
    mov ax,0x07c0    ;设置数据段地址，和代码段相同
    mov ds,ax

    mov ax,0xb800    ;设置现存段地址
    mov es,ax

    ;以下显示字符串
    mov si,message
    mov di,0
    mov cx,start-message
@g:
    mov al,[si]      ;ds:si -> al
    mov [es:di],al   ;al -> es:di
    inc di
    mov byte [es:di],0x07
    inc di
    inc si
    loop @g

    ;以下计算1到100的和
    xor ax,ax
    mov cx,1
@f:
    add ax,cx
    inc cx
    cmp cx,100
    jle @f

    ;以下计算累加和的每个数位
    xor cx,cx       ;设置堆栈段的段基地址
    mov ss,cx
    mov sp,cx

    mov bx,10
    xor cx,cx
@d:
    inc cx          ;保存位数
    xor dx,dx       ;dx:ax被除数, 余数在dx中, 商在ax中
    div bx
    or dl,0x30
    push dx
    cmp ax,0
    jne @d

    ;以下显示各个数位
@a:
    pop dx
    mov [es:di],dl
    inc di
    mov byte [es:di],0x07
    inc di
    loop @a         ;循环次数在cx中，就是前面保存的位数

    jmp near $

times 510-($-$$) db 0
                db 0x55,0xaa
