#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define BUFFER_SIZE 4000

extern unsigned out_ptr;
extern unsigned char in_buffer[BUFFER_SIZE + 1];
extern unsigned char out_buffer[BUFFER_SIZE + 1];

unsigned in_ptr = 0;
unsigned in_buff_size = 0;

void exit_success(void);
void exit_error(void);
unsigned convert_number(unsigned char *);
void flush_out_buffer(void);
unsigned apply_polynomial(const unsigned *coeffs, unsigned args, unsigned codepoint);

void readchar(unsigned char *c, int require) {
    if (in_ptr == BUFFER_SIZE || in_ptr == in_buff_size) {
        in_ptr = 0;
        in_buff_size = read(0, in_buffer, BUFFER_SIZE);
        if (in_buff_size == 0) {
            if (require) {
                exit_error();
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
                    exit_error();
                }
            }
        }
    }

    if (c < minval || c > 0x10FFFF) {
        exit_error();
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

int main(int argc, char *argv[]) {
    unsigned args = argc - 1;
    if (argc < 2) {
        exit_error();
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

/*
int main(int argc, char *argv[]) {
    unsigned args = 3;
    unsigned coeffs[] = {1000, 1000, 1000};

    ///
    while (1) {
        unsigned codepoint = read_codepoint();

        if (codepoint >= 0x80) {
            codepoint = apply_polynomial(coeffs, args, codepoint);
        }

        write_codepoint(codepoint);
    }


    return 0;
}
*/
