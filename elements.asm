        %define SYS_EXIT 60
        %define SYS_READ 0
        %define SYS_WRITE 1
        %define STDOUT 1
        %define EXIT_CODE_SUCCESS 0
        %define EXIT_CODE_ERROR 1
        %define MOD 0x10FF80
        %define BUFFER_SIZE 1001
        %define BUFFER_MAX_IDX 1000

        global exit_success
        global exit_error
        global convert_number

        global out_buffer
        global out_ptr
        global in_buffer

        extern flush_out_buffer

        section .bss
        out_ptr resb 4
        out_buffer resb BUFFER_SIZE
        in_buffer resb BUFFER_SIZE

        section .text

convert_number:
; Check if the string is empty.
        xor rcx, rcx
        mov cl, byte [rdi]
        test cl, cl
        jz exit_error

        xor rax, rax                   ; ret

        mov r8d, MOD
        mov r9d, 10

_loop_over_chars:
; czy s < 0 lub s > 9?
        sub cl, 0x30
        jl exit_error
        cmp cl, 0x9
        ja exit_error

        mul r9d
        add eax, ecx

; remainder liczenie
        mov edx, 0
        div r8d
        mov eax, edx

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
