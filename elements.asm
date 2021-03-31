        %define SYS_EXIT 60
        %define SYS_READ 0
        %define SYS_WRITE 1
        %define STDIN 0
        %define STDOUT 1
        %define EXIT_CODE_SUCCESS 0
        %define EXIT_CODE_ERROR 1
        %define UTF8_MODULO 0x10FF80
        %define DECIMAL_BASE 10
        %define BUFFER_SIZE 4001
        %define BUFFER_MAX_IDX 4000

        global exit_error
        global convert_number
        global readchar

        global read_2byte
        global read_3byte
        global read_4byte
        global run_main_read_write_loop
        global read_codepoint

        ;extern read_codepoint

        section .bss
        out_ptr resd 1
        in_ptr resd 1
        in_buff_size resd 1
        out_buffer resb BUFFER_SIZE
        in_buffer resb BUFFER_SIZE

        section .text

; takes a scrap register name as arg
; clobbers rdx
        %macro rax_modulo_utf8 1
        mov %1, rax
        mov rdx, 0x787c03a5c11c4499
        mul rdx
        mov rax, rdx
        shr rax, 0x13
        imul rdx, rax, UTF8_MODULO
        mov rax, %1
        sub rax, rdx
        %endmacro

; takes a scrap register name as arg
; clobbers rdx
        %macro eax_modulo_utf8 1
        mov %1, eax
        imul rax, rax, 0x3c3e01d3
        shr	rax, 0x32
        imul edx, eax, UTF8_MODULO
        mov	eax, %1
        sub	eax, edx
        %endmacro

readchar:
; rdi - ptr output, esi - require
; r8 - in_ptr, r9 - ptr (ptr*) output
        mov r10d, edi

        mov r8d, [in_ptr]
        cmp r8d, BUFFER_SIZE
        jz _readchar_fill_buffer
        cmp r8d, dword [in_buff_size]
        jz _readchar_fill_buffer
        jmp _readchar_finalize

_readchar_fill_buffer:
        mov [in_ptr], dword 0

        mov rax, SYS_READ
        mov rdi, STDIN
        mov rsi, in_buffer
        mov rdx, BUFFER_MAX_IDX
        syscall
        mov [in_buff_size], eax
        test eax, eax
        jnz _readchar_finalize
        test r10d, r10d
        jz exit_success
        jmp exit_error

_readchar_finalize:
        mov r8d, dword [in_ptr]
        lea r11, [in_buffer + r8]
        mov al, byte [r11]
        inc r8d
        mov [in_ptr], r8d
        ret

read_2byte:
        mov r9d, edi
        mov di, 0x1
        shl r9d, 0x6
        and r9d, 0x7c0
        call readchar
        and eax, 0x3f
        or eax, r9d
        ret

read_3byte:
        push rbp
        push rbx
        mov ebx, edi
        mov edi, 0x1
        shl ebx, 0xc
        and ebx, 0xf000
        sub rsp, 0x8
        call readchar
        mov edi, 0x1
        mov ebp, eax
        call readchar
        add rsp, 0x8
        and eax, 0x3f
        or ebx, eax
        mov eax, ebp
        shl eax, 0x6
        and eax, 0xfc0
        or eax, ebx
        pop rbx
        pop rbp
        ret

read_4byte:
        push r12
        push rbp
        push rbx
        mov ebx, edi
        mov edi, 0x1
        shl ebx, 0x12
        and ebx, 0x1c0000
        call readchar
        mov edi, 0x1
        mov r12d, eax
        call readchar
        mov edi, 0x1
        shl r12d, 0xc
        mov ebp, eax
        and r12d, 0x3f000
        call readchar
        and eax, 0x3f
        or ebx, eax
        or ebx, r12d
        mov r12d, ebp
        shl r12d, 0x6
        and r12d, 0xfc0
        or r12d, ebx
        cmp r12d, 0x10ffff
        jg _read4_error
        mov eax, r12d
        pop rbx
        pop rbp
        pop r12
        ret
_read4_error:
        call exit_error


 ;00000000004014d0 <read_codepoint>:
 ;  4014d0:	48 83 ec 18          	sub    rsp,0x18
 ;  4014d4:	31 ff                	xor    edi,edi
 ;  4014d6:	e8 e5 fc ff ff       	call   4011c0 <readchar>
 ;  4014db:	84 c0                	test   al,al
 ;  4014dd:	79 31                	jns    401510 <read_codepoint+0x40>
 ;  4014df:	89 c2                	mov    edx,eax
 ;  4014e1:	0f b6 f8             	movzx  edi,al
 ;  4014e4:	83 e2 e0             	and    edx,0xffffffe0
 ;  4014e7:	80 fa c0             	cmp    dl,0xc0
 ;  4014ea:	74 34                	je     401520 <read_codepoint+0x50>
 ;  4014ec:	89 c2                	mov    edx,eax
 ;  4014ee:	83 e2 f0             	and    edx,0xfffffff0
 ;  4014f1:	80 fa e0             	cmp    dl,0xe0
 ;  4014f4:	74 5a                	je     401550 <read_codepoint+0x80>
 ;  4014f6:	83 e0 f8             	and    eax,0xfffffff8
 ;  4014f9:	3c f0                	cmp    al,0xf0
 ;  4014fb:	74 43                	je     401540 <read_codepoint+0x70>
 ;  4014fd:	e8 b3 fe ff ff       	call   4013b5 <exit_error>
 ;  401502:	31 c0                	xor    eax,eax
 ;  401504:	48 83 c4 18          	add    rsp,0x18
 ;  401508:	c3                   	ret
 ;  401509:	0f 1f 80 00 00 00 00 	nop    DWORD PTR [rax+0x0]
 ;  401510:	0f b6 c0             	movzx  eax,al
 ;  401513:	48 83 c4 18          	add    rsp,0x18
 ;  401517:	c3                   	ret
 ;  401518:	0f 1f 84 00 00 00 00 	nop    DWORD PTR [rax+rax*1+0x0]
 ;  40151f:	00
 ;  401520:	e8 18 fd ff ff       	call   40123d <read_2byte>
 ;  401525:	ba 80 00 00 00       	mov    edx,0x80
 ;  40152a:	39 d0                	cmp    eax,edx
 ;  40152c:	73 d6                	jae    401504 <read_codepoint+0x34>
 ;  40152e:	89 44 24 0c          	mov    DWORD PTR [rsp+0xc],eax
 ;  401532:	e8 7e fe ff ff       	call   4013b5 <exit_error>
 ;  401537:	8b 44 24 0c          	mov    eax,DWORD PTR [rsp+0xc]
 ;  40153b:	48 83 c4 18          	add    rsp,0x18
 ;  40153f:	c3                   	ret
 ;  401540:	e8 0b ff ff ff       	call   401450 <read_4byte>
 ;  401545:	ba 00 00 01 00       	mov    edx,0x10000
 ;  40154a:	eb de                	jmp    40152a <read_codepoint+0x5a>
 ;  40154c:	0f 1f 40 00          	nop    DWORD PTR [rax+0x0]
 ;  401550:	e8 06 fd ff ff       	call   40125b <read_3byte>
 ;  401555:	ba 00 08 00 00       	mov    edx,0x800
 ;  40155a:	eb ce                	jmp    40152a <read_codepoint+0x5a>
 ;  40155c:	0f 1f 40 00          	nop    DWORD PTR [rax+0x0]


run_main_read_write_loop:
; rdi - ptr na coeffs, esi - args
        mov r12, rdi
        mov r13d, esi
_loop_rw:
        call read_codepoint
        cmp eax, 0x7f
        jbe _write_encoded_codepoint
        mov rdi, r12
        mov esi, r13d
        mov edx, eax
        call apply_polynomial
_write_encoded_codepoint:
        mov edi, eax
        call write_codepoint
        jmp _loop_rw

convert_number:
; Check if the string is empty.
        xor rcx, rcx
        mov cl, byte [rdi]
        test cl, cl
        jz exit_error

        xor rax, rax
        mov r8d, DECIMAL_BASE

_loop_over_chars:
; czy s < 0 lub s > 9?
        sub cl, '0'
        jl exit_error
        cmp cl, 0x9
        ja exit_error

        mul r8d
        add eax, ecx
        eax_modulo_utf8 r9d

        inc rdi
        mov cl, byte [rdi]             ; *s
        test cl, cl
        jnz _loop_over_chars

        ret

flush_out_buffer:
        mov r8d, [out_ptr]
        test r8, r8
        jz _return_from_flush

        mov rax, SYS_WRITE
        mov rdi, STDOUT
        mov rsi, out_buffer
        mov edx, [out_ptr]
        syscall

        test rax, rax
        jz _exit_write_error

        mov [out_ptr], word 0
_return_from_flush:
        ret
_exit_write_error:
        mov rdi, EXIT_CODE_ERROR
        jmp _exit

writechar:
        mov eax, [out_ptr]
        cmp eax, BUFFER_SIZE
        je _flush
_write_char:
        mov rdx, out_buffer
        mov rcx, rdi
        mov [rdx + rax], cl
        inc eax
        mov	[out_ptr], eax
        ret
_flush:
        push rdi
        call flush_out_buffer
        pop rdi
        mov eax, [out_ptr]
        jmp _write_char

apply_polynomial:
; rdi - coeffs 64, esi - args 32, edx - codepoint
; rax - wynik, i = r8d, codepoint = r9d
        mov r9d, edx
        sub r9d, 0x80
        xor rax, rax
        xor r8, r8
_coeffs_loop:
        mul r9
        mov r10d, [rdi]
        add rax, r10
        rax_modulo_utf8 r11

        lea rdi, [rdi+4]
        inc r8d
        cmp r8d, esi
        jne _coeffs_loop

        add eax, 0x80
        ret

exit_error:
        call flush_out_buffer
        mov rdi, EXIT_CODE_ERROR
        jmp _exit
exit_success:
        call flush_out_buffer
        mov rdi, EXIT_CODE_SUCCESS
_exit:
        mov rax, SYS_EXIT
        syscall

write_codepoint:

        mov r10d, edi
        cmp	edi, 0xffff
        ja	.L10
        cmp	edi, 0x7ff
        ja	.L11
        cmp	edi, 0x7f
        jbe	.L7
        shr	edi, 6
        or	edi, 0xffffffc0
        movzx	edi, dil
.L8:                                   ; write 2 bytes
        call	writechar
        mov edi, r10d
        and	edi, 0x3f                  ; last 6 bits mask
        or	dil, 0x80                   ; first bit mask
.L7:
        jmp	writechar                  ; write last char / 1 byte
.L11:
        shr	edi, 12
        or	edi, 0xffffffe0
        movzx	edi, dil
.L6:                                   ; write 3 bytes (without calculating)
        call	writechar
        mov edi, r10d
        shr	edi, 6
        and	edi, 0x3f
        or	dil, 0x80
        jmp	.L8                        ; write 2 remaining bytes
.L10:                                  ; write 4 bytes
        shr	edi, 18
        or	edi, 0xfffffff0
        movzx	edi, dil
        call	writechar
        mov edi, r10d
        shr	edi, 12
        and	edi, 0x3f
        or	dil, 0x80
        jmp	.L6


read_codepoint:
	sub	rsp, 24
	xor	edi, edi
	call	readchar
	test	al, al
	jns	.L10r
	mov	edx, eax
	movzx	edi, al
	and	edx, -32
	cmp	dl, -64
	je	.L11r
	mov	edx, eax
	and	edx, -16
	cmp	dl, -32
	je	.L12r
	and	eax, -8
	cmp	al, -16
	je	.L13r
	call	exit_error
	xor	eax, eax
.L1r:
	add	rsp, 24
	ret
.L10r:
	movzx	eax, al
	add	rsp, 24
	ret
.L11r:
	call	read_2byte
	mov	edx, 128
.L5r:
	cmp	eax, edx
	jnb	.L1r
	mov	DWORD [rsp+0xc], eax
	call	exit_error
	mov	eax, DWORD [rsp+0xc]
	add	rsp, 24
	ret
.L13r:
	call	read_4byte
	mov	edx, 65536
	jmp	.L5r
.L12r:
	call	read_3byte
	mov	edx, 2048
	jmp	.L5r
