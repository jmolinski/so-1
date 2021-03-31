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
int main(int argc, char *argv[]) {
    unsigned args = 3;
    unsigned coeffs[] = {1075041, 623420, 1};

    run_main_read_write_loop(coeffs, args);

    return 0;
}
*/

void main2(int argc, char* argv[]);

/*
int main(int argc, char *argv[]) {

    main2(argc, argv);

    return 0;
}
*/
