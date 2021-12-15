	mov ax,0xb800 ;显存地址
	mov es,ax     ;使用es访问显存

	mov byte [es:0x00],'L'
	mov byte [es:0x01],0x07
	mov byte [es:0x02],'a'
	mov byte [es:0x01],0x07
	mov byte [es:0x04],'b'
	mov byte [es:0x01],0x07
	mov byte [es:0x06],'e'
	mov byte [es:0x01],0x07
	mov byte [es:0x08],'l'
	mov byte [es:0x01],0x07
	mov byte [es:0x0a],' '
	mov byte [es:0x01],0x07
	mov byte [es:0x0c],'o'
	mov byte [es:0x01],0x07
	mov byte [es:0x0e],'f'
	mov byte [es:0x01],0x07
	mov byte [es:0x10],'f'
	mov byte [es:0x01],0x07
	mov byte [es:0x12],'s'
	mov byte [es:0x01],0x07
	mov byte [es:0x14],'e'
	mov byte [es:0x01],0x07
	mov byte [es:0x16],'t'
	mov byte [es:0x01],0x07
	mov byte [es:0x18],':'
	mov byte [es:0x01],0x07

	mov ax,number ;取得标号的汇编地址
	mov bx,10     ;除数

	mov cx,cs     ;取得当前代码段的段地址
	mov ds,cx     ;当前数据也在代码段中

	mov dx,0	  ;被除数的高位,dx:ax作为被除数, 商在ax中，余数在dx中
	div bx        ;dx:ax / bx即number / 10
	mov [0x7c00+number+0x00],dl ;个位数存放到number标号的0地址处

	xor dx,dx    ;清空dx
	div bx
	mov [0x7c00+number+0x01],dl

	xor dx,dx
	div bx
	mov [0x7c00+number+0x02],dl

	xor dx,dx
	div bx
	mov [0x7c00+number+0x03],dl

	xor dx,dx
	div bx
	mov [0x7c00+number+0x04],dl

	mov al,[0x7c00+number+0x04]
	add al,'0'
	mov [es:0x1a],al
	mov byte [es:0x1b],0x04

	mov al,[0x7c00+number+0x03]
	add al,'0'
	mov [es:0x1c],al
	mov byte [es:0x1d],0x04

	mov al,[0x7c00+number+0x02]
	add al,'0'
	mov [es:0x1e],al
	mov byte [es:0x1f],0x04

	mov al,[0x7c00+number+0x01]
	add al,'0'
	mov [es:0x20],al
	mov byte [es:0x21],0x04

	mov al,[0x7c00+number+0x00]
	add al,'0'
	mov [es:0x22],al
	mov byte [es:0x23],0x04

	mov byte [es:0x24],'D'
	mov byte [es:0x25],0x07

infi:
	jmp near infi

number:
	db 0,0,0,0,0

times 203 db 0
	db 0x55,0xaa
