#include <stdio.h> // for snprintf
#include <re2/re2.h>
#include <re2/stringpiece.h>

#include "re2_c.h"

using namespace std;

#define likely(x)   __builtin_expect((x),1)
#define unlikely(x) __builtin_expect((x),0)

#ifdef DEBUG
    // Usage examples: ASSERT(a > b),  ASSERT(foo() && "Opps, foo() reutrn 0");
    #define ASSERT(c) if (!(c))\
        { fprintf(stderr, "%s:%d Assert: %s\n", __FILE__, __LINE__, #c); abort(); }
#else
    #define ASSERT(c) ((void)0)
#endif

static void __attribute__((cold))
copy_errstr(char* buf, int buflen, const string& src) {
    if (!buf || buflen <= 0)
       return;

    int len = snprintf(buf, buflen - 1, "%s", src.c_str());
    if (len < 0)
        len = 0;

    buf[len] = '\0';
}

struct re2_pattern_t*
re2c_compile(const char* pattern, int pat_len, int* capture_num,
             char* errstr, int errstrlen) {
    RE2* pat = new RE2(re2::StringPiece(pattern, pat_len));
    if (pat && !pat->ok()) {
        copy_errstr(errstr, errstrlen, pat->error());
        delete pat;
        return 0;
    }

    if (capture_num)
        *capture_num = pat->NumberOfCapturingGroups();

    return (re2_pattern_t*)(void*)pat;
}

void
re2c_free(struct re2_pattern_t* pat) {
    delete (RE2*)(void*)pat;
}

int
re2c_getncap(struct re2_pattern_t* pattern) {
    RE2* pat = reinterpret_cast<RE2*>(pattern);
    return pat->NumberOfCapturingGroups();
}

int
re2c_match(const char* text, int text_len, struct re2_pattern_t* pattern) {
    RE2* re2 = (RE2*)(void*)pattern;
    if (unlikely(!re2))
        return 1;
    bool match = RE2::PartialMatch(re2::StringPiece(text, text_len), *re2);
    return match ? 0 : 1;
}

int
re2c_fmatch(const char* text, int text_len, struct re2_pattern_t* pattern,
            char* errstr, int errstrlen) {
    RE2* re2 = (RE2*)(void*)pattern;
    bool match = RE2::FullMatch(re2::StringPiece(text, text_len), *re2);
    return match ? 0 : 1;
}

class CaptureArgs {
public:
    CaptureArgs() { _capture_num = 0; _init = false;}
    CaptureArgs(int cap_num) { _init = false; Init(cap_num); }
    void Init(int cap_num);

    ~CaptureArgs();

    int getCaptureNum() const { return _capture_num; }
    RE2::Arg** getArgPtrVector() const { return _arg_ptr_vect; }

    // get i-th capture.
    const re2::StringPiece& getCapture(int idx) const {
        ASSERT(idx >= 0 && idx < _submatch_num);
        return _str_vect[idx];
    }

    // Convert _str_vect[i] to submatch[i]
    void Convert(RE2C_capture_t* cap);

private:
    #define ARG_PREALLOC_NUM 16
    int getPreallocNum() const { return ARG_PREALLOC_NUM; }

    RE2::Arg _args[ARG_PREALLOC_NUM];
    RE2::Arg* _arg_ptrs[ARG_PREALLOC_NUM];
    re2::StringPiece _strs[ARG_PREALLOC_NUM];

    RE2::Arg* _arg_vect;
    RE2::Arg** _arg_ptr_vect;
    re2::StringPiece* _str_vect;

    int _capture_num;
    bool _init;
    #undef ARG_PREALLOC_NUM
};

CaptureArgs::~CaptureArgs() {
    if (_capture_num > getPreallocNum()) {
        delete[] _arg_vect;
        delete[] _arg_ptr_vect;
        delete[] _str_vect;
    }
}

void
CaptureArgs::Init(int cap_num) {
    if (_init)
        return;

    _capture_num = cap_num;
    if (cap_num > getPreallocNum()) {
        _arg_vect = new RE2::Arg[cap_num];
        _arg_ptr_vect = new RE2::Arg*[cap_num];
        _str_vect = new re2::StringPiece[cap_num];
    } else {
        _arg_vect = _args;
        _arg_ptr_vect = _arg_ptrs;
        _str_vect = _strs;
    }

    RE2::Arg* arg_vect = _arg_vect;
    RE2::Arg** arg_ptr_vect = _arg_ptr_vect ;
    re2::StringPiece* str_vect = _str_vect ;

    for (int i = 0; i < cap_num; i++) {
        arg_ptr_vect[i] = arg_vect + i;
        arg_vect[i] = RE2::Arg(str_vect + i);
    }

    _init = true;
}

void
CaptureArgs::Convert(RE2C_capture_t* cap) {
    re2::StringPiece* str_vect = _str_vect;

    for (int i = 0, e = _capture_num; i < e; i++) {
        const re2::StringPiece& str = str_vect[i];
        cap[i].str = str.data();
        cap[i].len = str.length();
    }
}

int
re2c_matchn(const char* text, int text_len, struct re2_pattern_t* pattern,
            RE2C_capture_t* cap, int cap_num) {

    RE2* pat = reinterpret_cast<RE2*>(pattern);
    if (unlikely(!pat) || cap_num != pat->NumberOfCapturingGroups() || cap_num < 0)
        return 1;

    CaptureArgs ca(cap_num);
    if (RE2::PartialMatchN(re2::StringPiece(text, text_len),
                           *pat, ca.getArgPtrVector(), cap_num)) {
        ca.Convert(cap);
        return 0;
    }
    return 1;
}

int
re2c_fmatchn(const char* text, int text_len, struct re2_pattern_t* pattern,
             RE2C_capture_t* cap, int cap_num) {
    RE2* pat = reinterpret_cast<RE2*>(pattern);
    if (unlikely(!pat) || cap_num != pat->NumberOfCapturingGroups() || cap_num < 0)
        return 1;

    CaptureArgs ca(cap_num);
    if (RE2::FullMatchN(re2::StringPiece(text, text_len),
                        *pat, ca.getArgPtrVector(), cap_num)) {
        ca.Convert(cap);
        return 0;
    }

    return 1;
}
