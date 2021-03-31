; autor Jakub Molinski 491502

        SYS_EXIT equ 60
        SYS_READ equ 0
        SYS_WRITE equ 1
        STDIN equ 0
        STDOUT equ 1
        EXIT_CODE_SUCCESS equ 0
        EXIT_CODE_ERROR equ 1
        UTF8_MODULO equ 0x10ff80
        UNICODE_MAX_ENCODABLE equ 0x10ffff
        DECIMAL_BASE equ 10
        BUFFER_SIZE equ 4096
        BUFFER_MAX_INDEX equ 4095
        REQUIRED_FLAG equ 1

        MAX_UTF8_POINT_1B equ 0x7f
        SMALLEST_UTF8_POINT_2B equ 0x80
        MAX_UTF8_POINT_2B equ 0x7ff
        SMALLEST_UTF8_POINT_3B equ 0x800
        MAX_UTF8_POINT_3B equ 0xffff
        SMALLEST_UTF8_POINT_4B equ 0x10000

        BITMASK_8BIT_6YOUNGEST_BITS_ON equ 0x3f
        BITMASK_8BIT_OLDEST_BIT_ON equ 0x80
        BITMASK_8BIT_OLDEST_2BITS_ON equ 0xc0
        BITMASK_8BIT_OLDEST_3BITS_ON equ 0xe0
        BITMASK_8BIT_OLDEST_4BITS_ON equ 0xf0
        BITMASK_32BIT_OLDEST_26BITS_ON equ 0xffffffc0
        BITMASK_32BIT_OLDEST_27BITS_ON equ 0xffffffe0
        BITMASK_32BIT_OLDEST_28BITS_ON equ 0xfffffff0
        BITMASK_32BIT_OLDEST_29BITS_ON equ 0xfffffff8
        BITMASK_32BIT_7TO12_BITS_ON equ 0xfc0
        BITMASK_32BIT_8TO13_BITS_ON equ 0x7c0
        BITMASK_32BIT_13TO16_BITS_ON equ 0xf000
        BITMASK_32BIT_19TO21_BITS_ON equ 0x1c0000
        BITMASK_32BIT_13TO18_BITS_ON equ 0x3f000

        global _start

        section .bss

        out_ptr resd 1
        in_ptr resd 1
        in_buff_size resd 1
        out_buffer resb BUFFER_SIZE
        in_buffer resb BUFFER_SIZE

        section .text

; Performs fast modulo operation on rax register.
; Takes a register name as argument that can be used as temp store.
; Clobbers register rdx.
; Generated with gcc.
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

; Performs fast modulo operation on eax register.
; Takes a register name as argument that can be used as temp store.
; Clobbers register rdx.
; Generated with gcc.
        %macro eax_modulo_utf8 1
        mov %1, eax
        imul rax, rax, 0x3c3e01d3
        shr rax, 0x32
        imul edx, eax, UTF8_MODULO
        mov eax, %1
        sub eax, edx
        %endmacro

; Reads and returns one character from stdin. Used an internal buffer.
; Arguments rdi - ptr output, esi - is_REQUIRED_FLAG
; Clobbered registers r10, r8, rax, rdi, rsi, rdx, r11
readchar:
        mov r10d, edi
        mov r8d, [in_ptr]
        cmp r8d, BUFFER_SIZE
        jz _readchar_fill_buffer
        cmp r8d, dword [in_buff_size]
        jz _readchar_fill_buffer
        jmp _readchar_finalize
_readchar_fill_buffer:
        mov [in_ptr], dword 0
        mov eax, SYS_READ
        mov edi, STDIN
        mov esi, in_buffer
        mov edx, BUFFER_MAX_INDEX
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

; Read and decode 2 byte utf8 codepoint.
; Arguments - edi - first byte.
; Clobbered registers r9, rdi, rax
read_2byte:
        mov r9d, edi
        mov di, REQUIRED_FLAG
        shl r9d, 6
        and r9d, BITMASK_32BIT_8TO13_BITS_ON
        call readchar
        and eax, BITMASK_8BIT_6YOUNGEST_BITS_ON
        or eax, r9d
        ret

; Read and decode 3 byte utf8 codepoint.
; Arguments - edi - first byte.
; Clobbered registers r8, r10, r11, rax, rdi, rsi, rdx, rbp, rbx.
read_3byte:
        mov ebx, edi
        mov edi, REQUIRED_FLAG
        shl ebx, 12
        and ebx, BITMASK_32BIT_13TO16_BITS_ON
        call readchar
        mov edi, REQUIRED_FLAG
        mov ebp, eax
        call readchar
        and eax, BITMASK_8BIT_6YOUNGEST_BITS_ON
        or ebx, eax
        mov eax, ebp
        shl eax, 6
        and eax, BITMASK_32BIT_7TO12_BITS_ON
        or eax, ebx
        ret

; Read and decode 4 byte utf8 codepoint.
; Arguments - edi - first byte.
; Clobbered registers r8, r10, r11, rax, rdi, rsi, rdx, rbp, rbx.
read_4byte:
        push r12
        mov ebx, edi
        mov edi, REQUIRED_FLAG
        shl ebx, 18
        and ebx, BITMASK_32BIT_19TO21_BITS_ON
        call readchar
        mov edi, REQUIRED_FLAG
        mov r12d, eax
        call readchar
        mov edi, REQUIRED_FLAG
        shl r12d, 12
        mov ebp, eax
        and r12d, BITMASK_32BIT_13TO18_BITS_ON
        call readchar
        and eax, BITMASK_8BIT_6YOUNGEST_BITS_ON
        or ebx, eax
        or ebx, r12d
        mov r12d, ebp
        shl r12d, 6
        and r12d, BITMASK_32BIT_7TO12_BITS_ON
        or r12d, ebx
        cmp r12d, UNICODE_MAX_ENCODABLE
        jg _read4_error
        mov eax, r12d
        pop r12
        ret
_read4_error:
        call exit_error

; Converts a bytestring to integer modulo utf8_max.
; Arguments rdi - address of bytestring first byte.
; Clobbers registers rcx, rax, r8, rdi.
; Returns the number in eax.
convert_number:
; Check if the string is empty.
        xor ecx, ecx
        mov cl, [rdi]
        test cl, cl
        jz exit_error
        xor eax, eax
        mov r8d, DECIMAL_BASE
_loop_over_chars:
; Check if cl is between '0' and '9' and convert it to a number
        sub cl, '0'
        jl exit_error
        cmp cl, 9
        ja exit_error
        mul r8d
        add eax, ecx
        eax_modulo_utf8 r9d
        inc rdi
        mov cl, byte [rdi]
        test cl, cl
        jnz _loop_over_chars
        ret

; Flushes the output buffer.
; Takes no arguments.
; Clobbers registers r8, rax, rdi, rsi, rdx.
flush_out_buffer:
        mov r8d, [out_ptr]
        test r8d, r8d
        jz _return_from_flush
        mov eax, SYS_WRITE
        mov edi, STDOUT
        mov rsi, out_buffer
        mov edx, [out_ptr]
        syscall
        test eax, eax
        jz _exit_write_error

        mov [out_ptr], word 0
_return_from_flush:
        ret
_exit_write_error:
        mov rdi, EXIT_CODE_ERROR
        jmp _exit

; Writes a single byte to stdout. Uses an internal buffer.
; Arguments - dl - byte to write.
; Clobbers registers rdi, rax, rdx, rcx, rsi, r8.
writechar:
        mov eax, [out_ptr]
        cmp eax, BUFFER_SIZE
        je _flush
_write_char:
        mov [out_buffer + rax], di
        inc eax
        mov [out_ptr], eax
        ret
_flush:
        push rdi
        call flush_out_buffer
        pop rdi
        xor eax, eax
        jmp _write_char

; Encodes and writes an unicode codepoint
; Arguments edi - codepoint.
; Clobbers registers rdi, rax, rsi, rdx, r8, r10, r11, r12.
; Returns the codepoint in eax.
write_codepoint:
        mov r10d, edi
        cmp edi, MAX_UTF8_POINT_3B
        ja _write_4bytes
        cmp edi, MAX_UTF8_POINT_2B
        ja _write_3bytes
        cmp edi, MAX_UTF8_POINT_1B
        jbe _write_1byte
        shr edi, 6
        or edi, BITMASK_32BIT_OLDEST_26BITS_ON
        movzx edi, dil
_write_2bytes:
        call writechar
        mov edi, r10d
        and edi, BITMASK_8BIT_6YOUNGEST_BITS_ON
        or dil, BITMASK_8BIT_OLDEST_BIT_ON
_write_1byte:
        jmp writechar
_write_3bytes:
        shr edi, 12
        or edi, BITMASK_32BIT_OLDEST_27BITS_ON
        movzx edi, dil
_write_3bytes_wo_shift:
        call writechar
        mov edi, r10d
        shr edi, 6
        and edi, BITMASK_8BIT_6YOUNGEST_BITS_ON
        or dil, BITMASK_8BIT_OLDEST_BIT_ON
        jmp _write_2bytes
_write_4bytes:
        shr edi, 18
        or edi, BITMASK_32BIT_OLDEST_28BITS_ON
        movzx edi, dil
        call writechar
        mov edi, r10d
        shr edi, 12
        and edi, BITMASK_8BIT_6YOUNGEST_BITS_ON
        or dil, BITMASK_8BIT_OLDEST_BIT_ON
        jmp _write_3bytes_wo_shift

; Reads and decodes a unicode utf-8 encoded codepoint.
; Takes no arguments.
; Clobbers registers rdi, rax, rsi, rdx, r8, r10, r11, r12.
; Returns the codepoint in eax.
read_codepoint:
        xor edi, edi
        call readchar
        test al, al
        jns _return_1byte
        mov edx, eax
        movzx edi, al
        and edx, BITMASK_32BIT_OLDEST_27BITS_ON
        cmp dl, BITMASK_8BIT_OLDEST_2BITS_ON
        je _return_2bytes
        mov edx, eax
        and edx, BITMASK_32BIT_OLDEST_28BITS_ON
        cmp dl, BITMASK_8BIT_OLDEST_3BITS_ON
        je _return_3bytes
        and eax, BITMASK_32BIT_OLDEST_29BITS_ON
        cmp al, BITMASK_8BIT_OLDEST_4BITS_ON
        je _return_4bytes
        call exit_error
_return_1byte:
        movzx eax, al
        ret
_return_2bytes:
        call read_2byte
        mov edx, SMALLEST_UTF8_POINT_2B
        jmp _check_validity_and_return
_return_3bytes:
        call read_3byte
        mov edx, SMALLEST_UTF8_POINT_3B
        jmp _check_validity_and_return
_return_4bytes:
        call read_4byte
        mov edx, SMALLEST_UTF8_POINT_4B
_check_validity_and_return:
; edx is equal to the smallest codepoint that can be encoded on n bytes.
        cmp eax, edx
        jnb _return_codepoint
        call exit_error
_return_codepoint:
        ret

; Calculates the polynomial value at point = codepoint, modulo utf8_max.
; Arguments rdi - address of polynomial coefficients, esi - number or polynomial coefficients,
; edx - codepoint.
; Clobbers registers r9, rax, r8, r10, rdi.
; Returns the calculated value in eax.
apply_polynomial:
        mov r9d, edx
        sub r9d, SMALLEST_UTF8_POINT_2B
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
        add eax, SMALLEST_UTF8_POINT_2B
        ret

; Runs the main read - decode - apply polynomial - encode - write loop.
; Arguments rdi - address of polynomial coefficients, esi - number or polynomial coefficients.
; Never returns (calls exit syscall).
run_main_read_write_loop:
        mov r12, rdi
        mov r13d, esi
_loop_rw:
        call read_codepoint
        cmp eax, MAX_UTF8_POINT_1B
        jbe _write_encoded_codepoint
        mov rdi, r12
        mov esi, r13d
        mov edx, eax
        call apply_polynomial
_write_encoded_codepoint:
        mov edi, eax
        call write_codepoint
        jmp _loop_rw

; Main function of the program.
; Arguments rdi - program arguments count, rsi - address of the first argument
; Exits through a syscall.
_start:
        pop rdi                        ; Pop the number or arguments.
        mov r13, rsp

        mov rbp, rsp
        sub rsp, 8
        mov r15d, edi
        dec r15d
        je _exit_too_few_args
        sub edi, 2
        mov eax, edi
        lea rax, [rax*4]
        sub rsp, rax
        mov r14, rsp
        xor ebx, ebx
        inc ebx
        mov r12d, edi
_convert_and_save_args_loop:
        mov eax, ebx
        mov rdi, [r13+rax*8]
        call convert_number
        mov [r14+r12*4], eax
        dec r12
        inc ebx
        cmp r15d, ebx
        jnb _convert_and_save_args_loop
        mov esi, r15d
        mov rdi, r14
        call run_main_read_write_loop
_exit_too_few_args:
        call exit_error

; exit_error and exit_success are 2 possible ways to end the execution.
; They call exit syscall with 0 or nonzero codes.
; Take no arguments.
exit_error:
        call flush_out_buffer
        mov edi, EXIT_CODE_ERROR
        jmp _exit
exit_success:
        call flush_out_buffer
        mov edi, EXIT_CODE_SUCCESS
_exit:
        mov eax, SYS_EXIT
        syscall
