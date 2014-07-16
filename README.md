C and Lua wrappers for RE2
=========================

C and Lua wrapper for RE2 regular expression library. The Lua wrapper is built on
top of C wrapper.

Lua Functions
=============

The Lua wrapper (lua-re2.lua) exposes following functions:

new
---
`syntax: instance = new([max-capture])`

Create an instance which pre-allocate some data structures for captures, to obviate
the need of allocating them each time `match` is called.

The default value of the parameter `max-capture` is 40.

compile
-------
`syntax: pattern, capture_num, err_msg = compile(pattern, [options, max_mem])`

Pre-compile the pattern string. Additional options for the regex engine can be passed by
the `options` and `max_mem`; they are corresponding to RE2's `re2::RE2::Options` except
that the `options` is using single character, instead of bitmask, to pass the boolean
options. The respondance between `options` and RE2's `re2::RE2::Options` are following:

|option char|re2::RE2::Options| meaning| default value|
|-----------|-----------------|--------|--------------|
| u         | utf8            |text and pattern are UTF-8; otherwise Latin-1 | true |
| p         | posix_syntax    |restrict regexps to POSIX egrep syntax | false |
| m         | longest_match   |search for longest match, not first match | false |
| e         | log_errors      |log syntax and execution errors to ERROR | true |
| l         | literal         |interpret string as literal, not regexp  | false |
| n         | never_nl        |never match \n, even if it is in regexp  | false |
| d         | dot_nl          |dot matches everything including new line | false |
| c         | never_capture   |parse all parens as non-capturing         | false |
| s         | case_sensitive  |match is case-sensitive (regexp can override with (?i) unless in posix_syntax mode) | true |

match
------
`syntax: result, captures, errmsg = match(instance, pattern, text, cap_idx)`

Match the given pre-compiled `pattern` against the `text`. It returns three variables:

 | `result` | non-nil if maches, nil otherwise |
 | `captures` | the specified capture(s), see bellow |
 | `errmsg`   | error message if something wrong took place |

The input parameter `cap_idx` can take one of the following values:
 | 0 or nil | do not return any captures |
 | -1 | return all captures in an array |
 | 1 .. the-number-of-capture | return particular capture |

match_nocap
-----------
`syntax: match_nocap(pattern, text)`

Match the pre-compiled `pattern` against the `text`, return non-nil if it was successful,
or nil otherwise. It does not return any captures no matter pattern contains capture or not.


C Funtions
==========
  The interface functions are self-descriptive. Please check the `re2c_c.h` for details.
