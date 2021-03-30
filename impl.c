#include <stdlib.h>

void exit_error(void);
unsigned convert_number(unsigned char *);
unsigned apply_polynomial(const unsigned *coeffs, unsigned args, unsigned codepoint);
void write_codepoint(unsigned c);

unsigned char readchar(unsigned require);

unsigned read_2byte(unsigned char first) {
    unsigned char second = readchar(1);
    return ((unsigned short)(first & 0x1f) << 6) | ((unsigned short)(second & 0x3f));
}

unsigned read_3byte(unsigned char first) {
    unsigned char second = readchar(1);
    unsigned char third = readchar(1);
    return ((unsigned short)(first & 0x0f) << 12) | ((unsigned short)(second & 0x3f) << 6) |
           ((unsigned short)(third & 0x3f));
}

unsigned read_4byte(unsigned char first) {
    unsigned char second = readchar(1);
    unsigned char third = readchar(1);
    unsigned char fourth = readchar(1);
    unsigned c = ((long)(first & 0x07) << 18) | ((long)(second & 0x3f) << 12) |
                 ((long)(third & 0x3f) << 6) | ((long)(fourth & 0x3f));
    if (c > 0x10FFFF) {
        exit_error();
    }
    return c;
}

unsigned read_codepoint() {
    unsigned c = 0;
    unsigned char first = readchar(0);

    int minval = 0;
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
