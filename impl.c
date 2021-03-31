void exit_error(void);
unsigned convert_number(unsigned char *);

unsigned char readchar(unsigned char require);
unsigned read_2byte(unsigned char first);
unsigned read_3byte(unsigned char first);
unsigned read_4byte(unsigned char first);
void run_main_read_write_loop(unsigned *coeffs, unsigned args);
/*
unsigned read_codepoint() {
    unsigned c = 0;
    unsigned char first = readchar(0);

    unsigned minval = 0;
    if (first < 0x80) {
        return first;
    } else if ((first & 0xe0) == 0xc0) {
        c = read_2byte(first);
        minval = 0x80;
    } else if ((first & 0xf0) == 0xe0) {
        c = read_3byte(first);
        minval = 0x800;
    } else if ((first & 0xf8) == 0xf0) {
        c = read_4byte(first);
        minval = 0x10000;
    } else {
        exit_error();
    }

    if (c < minval) {
        exit_error();
    }

    return c;
}
 */

/*
read_codepoint:
sub    rsp,0x18
xor    edi,edi
call   readchar
test   al,al
jns    4014f0 <read_codepoint+0x40>
mov    edx,eax
movzx  edi,al
and    edx,0xffffffe0
cmp    dl,0xc0
je     401500 <read_codepoint+0x50>
mov    edx,eax
and    edx,0xfffffff0
cmp    dl,0xe0
je     401530 <read_codepoint+0x80>
and    eax,0xfffffff8
cmp    al,0xf0
je     401520 <read_codepoint+0x70>
call   exit_error
xor    eax,eax
add    rsp,0x18
ret

movzx  eax,al
add    rsp,0x18
ret
call   read_2byte
mov    edx,0x80
cmp    eax,edx
jae    4014e4 <read_codepoint+0x34>
mov    DWORD [rsp+0xc],eax
call   401421 <exit_error>
mov    eax,DWORD [rsp+0xc]
add    rsp,0x18
ret
call   read_4byte
mov    edx,0x10000
jmp    40150a <read_codepoint+0x5a>
call   read_3byte
mov    edx,0x800
jmp    40150a <read_codepoint+0x5a>
 */

int main(int argc, char *argv[]) {
    unsigned args = argc - 1;
    if (argc == 0) {
        exit_error();
    }

    unsigned coeffs[args - 1];

    unsigned *coeff_ptr = &coeffs[args - 1];
    for (unsigned i = 1; i <= args; i++) {
        unsigned a = convert_number((unsigned char *)argv[i]);
        *coeff_ptr = a;
        coeff_ptr--;
        // coeffs[args - i] = a;
    }

    run_main_read_write_loop(coeffs, args);
}

/*
int main(int argc, char *argv[]) {
    unsigned args = 3;
    unsigned coeffs[] = {1075041, 623420, 1};

    run_main_read_write_loop(coeffs, args);

    return 0;
}
*/