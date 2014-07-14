#ifndef _RE2_C_H_
#define _RE2_C_H_

#ifdef __cplusplus
extern "C" {
#endif

#ifdef BUILDING_LIB
#define RE2C_EXPORT __attribute__ ((visibility ("protected")))
#else
#define RE2C_EXPORT __attribute__ ((visibility ("default")))
#endif

struct re2_pattern_t;

/****************************************************************************
 *
 * The correspondance between the single-char flags and re2::RE2::Options
 *
 * char,re2::RE2::Options,default-val,meaning
 * ==============================
 * u   utf8             (true)  text and pattern are UTF-8; otherwise Latin-1
 * p   posix_syntax     (false) restrict regexps to POSIX egrep syntax
 * m   longest_match    (false) search for longest match, not first match
 * e   log_errors       (true)  log syntax and execution errors to ERROR
 * n/a max_mem          (see below)  approx. max memory footprint of RE2
 * l   literal          (false) interpret string as literal, not regexp
 * n   never_nl         (false) never match \n, even if it is in regexp
 * d   dot_nl           (false) dot matches everything including new line
 * c   never_capture    (false) parse all parens as non-capturing
 * i   case_sensitive   (true)  match is case-sensitive (regexp can override
 *                      with (?i) unless in posix_syntax mode)
 *
 *  The lower-case char is to turn on (i.e set value to true), while the
 *  corresponding upper-case is to turn the flag off.
 *
 ****************************************************************************
 */

/* Compile the pattern. If it was successful, the compiled pattern is returned
 * if <submatch_num> is not-NULL, it is set to be the number of submatches the
 * pattern has; <errstr> and <errstrlen> is not accessed or deferenced in this
 * case. If it was not successful, NULL is returned; in the meantime, error
 * message is returned via <errstr> if it's non-NULL.
 *
 * RE2 options are passed via <re2_options> and <max_mem>, where <re2_options>
 * is a string, each character turning on or off an boolean option (see the
 * above comment). if <max_mem> take value 0, default value is used.
 */
struct re2_pattern_t* re2c_compile(const char* pattern,
                                   int pat_len, int* submatch_num,
                                   char* errstr, int errstrlen,
                                   const char* re2_options,
                                   int max_mem) RE2C_EXPORT;

/* Free the pre-compiled pattern */
void re2c_free(struct re2_pattern_t*) RE2C_EXPORT;

/* Return the number of captures the pattern have */
int re2c_getncap(struct re2_pattern_t*) RE2C_EXPORT;

/* Perform partial match. the regex may have submatches, but the caller
 * doesn't care what they are. Return 0 on success, 1 otherwise.
 */
int re2c_match(const char* text, int text_len,
               struct re2_pattern_t* pattern) RE2C_EXPORT;


/* Perform partial match and return the submatches. Return 0 on success,
 * 1 otherwise.
 * NOTE: the number of sub-match (submatch_num) must be consisit with the
 *   one returned from re2c_compile().
 */

typedef struct {
    const char* str;
    int len;
} RE2C_capture_t;

int re2c_matchn(const char* text, int text_len, struct re2_pattern_t* pattern,
                RE2C_capture_t*, int capture_num) RE2C_EXPORT;

/* Similar to re2c_match() except that the entire text is matching
 * the pattern.
 */
int re2c_fmatch(const char* text, int text_len,
                struct re2_pattern_t* pattern) RE2C_EXPORT;

/* Similar to re2c_matchn() except that the entire text is matching
 * the pattern.
 */
int re2c_fmatchn(const char* text, int text_len, struct re2_pattern_t* pattern,
                 RE2C_capture_t*, int capture_num,
                 char* errstr, int errstrlen) RE2C_EXPORT;

#ifdef __cplusplus
}
#endif

#endif /* _RE2_C_H_ */
