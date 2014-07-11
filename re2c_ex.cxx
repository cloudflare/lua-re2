#include <stdio.h>
#include <string.h>
#include "re2_c.h"

#define ERRSTR_LEN 256
static char errstr[ERRSTR_LEN];

bool
ex1() {
    //const char* pat_str = "([0-9]+)$";
    const char* pat_str = "([a-zA-Z]+)\\\\";
    struct re2_pattern_t* pat = re2c_compile(pat_str, strlen(pat_str), 0, errstr, ERRSTR_LEN);
    if (!pat) {
        fprintf(stderr, "Compile fail: %s\n", errstr);
        return false;
    }

    const char* text = "Posted\\ May 12, 2014";
    int res = re2c_match(text, (int)strlen(text), pat);
    re2c_free(pat);
    return res == 0;
}

bool
ex2() {
    int cap_num;
    struct re2_pattern_t* pat;
    const char pat_str[] = "([a-zA-Z]+) *\0([a-zA-Z]+)";
    pat = re2c_compile(pat_str, sizeof(pat_str)-1, &cap_num, 0, 0);
    if (!pat)
        return false;

    RE2C_capture_t cap[100];
    const char text[] = "Posted \0May 12, 2014";
    int res = re2c_matchn(text, sizeof(text) - 1, pat, cap, cap_num);
    if (res == 0) {
       for (int i = 0, e = cap_num; i < e; i++) {
            fprintf(stdout, "submatch %i %.*s\n", i, cap[i].len, cap[i].str);
       }
    }

    re2c_free(pat);
    return res == 0;
}

int
main(int argc, char** argv) {
    fprintf(stdout, "ex1 %s\n", ex1() ? "succ" : "fail");
    fprintf(stdout, "ex2 %s\n", ex2() ? "succ" : "fail");
    return 0;
}
