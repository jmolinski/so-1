        %define SYS_EXIT 60
        %define SYS_READ 0
        %define SYS_WRITE 1
        %define STDIN 0
        %define STDOUT 1
        %define EXIT_CODE_SUCCESS 0
        %define EXIT_CODE_ERROR 1
        %define UTF8_MODULO 0x10FF80
        %define BUFFER_SIZE 4001
        %define BUFFER_MAX_IDX 4000

        global exit_error
        global convert_number
        global apply_polynomial
        global readchar
        global flush_out_buffer
        global writechar

        global out_buffer
        global out_ptr

        section .bss
        out_ptr resb 4
        in_ptr resb 4
        in_buff_size resb 4
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
        mov r9, rdi
        mov r10d, esi

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
        cmp rax, 0
        jnz _readchar_finalize
        cmp r10d, 0
        jz exit_success
        jmp exit_error

_readchar_finalize:
        mov r8d, dword [in_ptr]
        lea r11, [in_buffer + r8]
        mov al, byte [r11]
        mov [r9], al
        mov r8d, dword [in_ptr]
        inc r8d
        mov [in_ptr], r8d
        ret

convert_number:
; Check if the string is empty.
        xor rcx, rcx
        mov cl, byte [rdi]
        test cl, cl
        jz exit_error

        xor rax, rax
        mov r8d, 10

_loop_over_chars:
; czy s < 0 lub s > 9?
        sub cl, 0x30
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
        cmp r8, 0
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
        mov r12, EXIT_CODE_ERROR
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
        mov r12, EXIT_CODE_ERROR
        call flush_out_buffer
        jmp _exit
exit_success:
        mov r12, EXIT_CODE_SUCCESS
        call flush_out_buffer
_exit:
        mov rax, SYS_EXIT
        mov rdi, r12
        syscall
