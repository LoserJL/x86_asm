    jmp near start

mytext db 'L',0x07,'a',0x07,'b',0x07,'e',0x07,'l',0x07,' ',0x07, \
          'o',0x07,'f',0x07,'f',0x07,'s',0x07,'e',0x07,'t',0x07,':',0x07

number db 0,0,0,0,0

start:
    mov ax,0x07c0    ;设置数据段地址，和代码段相同
    mov ds,ax

    mov ax,0xb800    ;设置现存段地址
    mov es,ax

    cld              ;将标志寄存器flag的方向标志位df清零,使si和di自动增加，如果df=1，则si和di自动减小
    mov si,mytext    ;ds:si为源地址
    mov di,0         ;es:di为目的地址
    mov cx,(number-mytext)/2
    rep movsw

    mov ax,number

    mov bx,ax       ;用于后面将余数保存到number标号代表的内存处
    mov cx,5
    mov si,10
digit:
    xor dx,dx
    div si          ;dx:ax / si, 即nubmer/10
    mov [bx],dl     ;把余数保存到number内存处
    inc bx          ;bx自加1，只想number的第二个（索引1）地址处
    loop digit

    mov bx,number
    mov si,4
show:
    mov al,[bx+si]
    add al,'0'
    mov ah,0x04
    mov [es:di],ax
    add di,2
    dec si
    jns show

    mov word [es:di],0x0744

    jmp near $       ;$代表该行行首的地址

times 510-($-$$) db 0 ;$$代表整个程序的首地址
                 db 0x55,0xaa