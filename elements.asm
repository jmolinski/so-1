        %define SYS_EXIT 60
        %define SYS_READ 0
        %define SYS_WRITE 1
        %define STDIN 0
        %define STDOUT 1
        %define EXIT_CODE_SUCCESS 0
        %define EXIT_CODE_ERROR 1
        %define UTF8_MODULO 0x10FF80
        %define DECIMAL_BASE 10
        %define BUFFER_SIZE 4096
        %define BUFFER_MAX_INDEX 4095

        global  _start
        global main2

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
        mov rdx, BUFFER_MAX_INDEX
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


;int main(int argc, char *argv[]) {
 ;    unsigned args = argc - 1;
 ;    if (argc == 0) {
 ;        exit_error();
 ;    }
 ;
 ;    unsigned coeffs[args - 1];
 ;
 ;    unsigned *coeff_ptr = &coeffs[args - 1];
 ;    for (unsigned i = 1; i <= args; i++) {
 ;        unsigned a = convert_number((unsigned char *)argv[i]);
 ;        *coeff_ptr = a;
 ;        coeff_ptr--;
 ;        // coeffs[args - i] = a;
 ;    }
 ;
 ;    run_main_read_write_loop(coeffs, args);
 ;}

main2:
; założenia:

; rdi - 1st arg (argc), rsi - 2nd arg (argv)

	mov	rbp, rsp             ; original stack ptr = rbp
	sub	rsp, 8    ;
	mov	r15d, edi            ; r15 = argc
	sub	r15d, 1             ; r15 = args
	je	_exit_too_few_args ; args == 0 => goto exit
	mov	r13, rsi            ; r13 = argv
	sub	edi, 2              ; argc = argc - 2
	mov	eax, edi
	lea	rax, [rax*4]        ; eax = r * (args - 1)
	sub	rsp, rax            ; alokacja tablicy!!!
	mov	r14, rsp            ; r14 = stack ptr (coeffs_ptr?)
	mov [arr_ptr], r14
	mov	ebx, 1              ; ebx = 1
	mov	r12d, edi           ; r12d = args - 1
_convert_and_save_args_loop:
	mov	eax, ebx
	mov	rdi, [r13+rax*8]
	call	convert_number
	mov	DWORD [r14+r12*4], eax
	dec r12
	inc	ebx
	cmp	r15d, ebx
	jnb	_convert_and_save_args_loop

	mov	esi, r15d
	mov	rdi, r14
	call	run_main_read_write_loop
_exit_too_few_args:
	call	exit_error

