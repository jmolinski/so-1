#include <stdlib.h>
#include <unistd.h>

#define MOD 0x10FF80
#define BUFFER_SIZE 4000

unsigned char out_buffer[BUFFER_SIZE + 1];
unsigned char in_buffer[BUFFER_SIZE + 1];

unsigned in_ptr = 0, out_ptr = 0;
unsigned in_buff_size = 0;

void flush_out_buffer() {
    if (out_ptr == 0) {
        return;
    }
    int ret = write(1, &out_buffer, out_ptr);
    if (ret == 0) {
        exit(1);
    }
    out_ptr = 0;
}

void error() {
    flush_out_buffer();
    exit(1);
}

void exit_success() {
    flush_out_buffer();
    exit(0);
}

unsigned convert_number(unsigned char *s) {
    if (*s == '\0') {
        error();
    }

    unsigned ret = 0;

    while (*s != '\0') {
        if (*s < '0' || *s > '9') {
            error();
        }

        ret = (ret * 10 + (*s - '0')) % MOD;
        s++;
    }

    return ret;
}

unsigned apply_polynomial(const unsigned *coeffs, unsigned args, unsigned codepoint) {
    codepoint -= 0x80;

    unsigned long long ret = 0;
    for (int i = 0; i < args; i++) {
        ret *= codepoint;
        ret += coeffs[i];
        ret %= MOD;
    }

    ret += 0x80;
    return ret;
}

void readchar(unsigned char *c, int require) {
    if (in_ptr == BUFFER_SIZE || in_ptr == in_buff_size) {
        in_ptr = 0;
        in_buff_size = read(0, in_buffer, BUFFER_SIZE);
        if (in_buff_size == 0) {
            if (require) {
                error();
            }
            exit_success();
        }
    }

    *c = in_buffer[in_ptr];
    in_ptr++;
}

unsigned read_codepoint() {
    unsigned c = 0;
    unsigned char first;
    readchar(&first, 0);

    int minval = 0;
    if (first < 0x80) {
        c = first;
    } else {
        unsigned char second;
        readchar(&second, 1);

        minval = 0x80;
        if ((first & 0xe0) == 0xc0) {
            c = ((long)(first & 0x1f) << 6) | ((long)(second & 0x3f) << 0);
        } else {
            unsigned char third;
            readchar(&third, 1);

            minval = 0x800;
            if ((first & 0xf0) == 0xe0) {
                c = ((long)(first & 0x0f) << 12) | ((long)(second & 0x3f) << 6) |
                    ((long)(third & 0x3f) << 0);
            } else {
                unsigned char fourth;
                readchar(&fourth, 1);

                minval = 0x10000;
                if ((first & 0xf8) == 0xf0 && (first <= 0xf4)) {
                    c = ((long)(first & 0x07) << 18) | ((long)(second & 0x3f) << 12) |
                        ((long)(third & 0x3f) << 6) | ((long)(fourth & 0x3f) << 0);
                } else {
                    error();
                }
            }
        }
    }

    if (c < minval || c > 0x10FFFF) {
        error();
    }

    return (int)c;
}

void write_codepoint(unsigned c) {
    unsigned char s[4];
    unsigned len;

    if (c >= (1L << 16)) {
        s[0] = 0xf0 | (c >> 18);
        s[1] = 0x80 | ((c >> 12) & 0x3f);
        s[2] = 0x80 | ((c >> 6) & 0x3f);
        s[3] = 0x80 | ((c >> 0) & 0x3f);
        len = 4;
    } else if (c >= (1L << 11)) {
        s[0] = 0xe0 | (c >> 12);
        s[1] = 0x80 | ((c >> 6) & 0x3f);
        s[2] = 0x80 | ((c >> 0) & 0x3f);
        len = 3;
    } else if (c >= (1L << 7)) {
        s[0] = 0xc0 | (c >> 6);
        s[1] = 0x80 | ((c >> 0) & 0x3f);
        len = 2;
    } else {
        s[0] = c;
        len = 1;
    }

    for (unsigned i = 0; i < len; i++) {
        if (out_ptr == BUFFER_SIZE) {
            flush_out_buffer();
        }
        out_buffer[out_ptr] = s[i];
        out_ptr++;
    }
}

/*
void write_codepoint(const unsigned c) {
    unsigned char s;
    if (c >= (1L << 16)) {
        s = 0xf0 | (c >> 18);
        writechar(s);
        s = 0x80 | ((c >> 12) & 0x3f);
        writechar(s);
        s = 0x80 | ((c >> 6) & 0x3f);
        writechar(s);
        s = 0x80 | ((c >> 0) & 0x3f);
        writechar(s);
    } else if (c >= (1L << 11)) {
        s = 0xe0 | (c >> 12);
        writechar(s);
        s = 0x80 | ((c >> 6) & 0x3f);
        writechar(s);
        s = 0x80 | ((c >> 0) & 0x3f);
        writechar(s);
    } else if (c >= (1L << 7)) {
        s = 0xc0 | (c >> 6);
        writechar(s);
        s = 0x80 | ((c >> 0) & 0x3f);
        writechar(s);
    } else {
        s = c;
        writechar(s);
    }
}
*/

int main(int argc, char *argv[]) {
    unsigned args = argc - 1;
    if (argc < 2) {
        error();
    }

    unsigned *coeffs = malloc(sizeof(unsigned) * args);
    for (unsigned i = 1; i < argc; i++) {
        unsigned a = convert_number((unsigned char *)argv[i]);
        coeffs[args - i] = a;
    }

    while (1) {
        unsigned codepoint = read_codepoint();

        if (codepoint >= 0x80) {
            codepoint = apply_polynomial(coeffs, args, codepoint);
        }

        write_codepoint(codepoint);
    }

    return 0;
}
