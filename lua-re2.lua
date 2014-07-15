--[[
  Copyright (c) 2014 CloudFlare, Inc. All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

     * Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above
  copyright notice, this list of conditions and the following disclaimer
  in the documentation and/or other materials provided with the
  distribution.
     * Neither the name of CloudFlare, Inc. nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

--[[
    This module is a thin Lua wrapper for RE2 lib. It built on top on RE2
  C wrapper (libre2c.so) which, in turn, relies on libre.so.

   This module exports following functions:
   ----------------------------------------
    o. new(max_cap):
        Create an instance of this module, "max_cap" indicates the maximum
        number of captures regular expression could have. The instance will
        pre-create some data structures about captures to avoid the cost of
        allocating them each time match() is called.

    o. compile(pattern):
        compile the pattern string. Return pre-compiled pattern on success,
        or nil otherwise.

    o. match_nocap(pattern, text)
        Match the pattern agaist the text. The pattern could have capture,
      but the values of the captures are not returned back to the caller.

    o. match(self, pattern, text, cap_idx)
        Match the pattern agaist the text. Return non-nil along with the
      specified capture(s).

   Usage example:
   --------------

    local re2 = require "lua-re2"
    local inst = re2.new()
    local pat = re2_inst.compile("the-pattern-string")
    local r, caps = re2_inst.match(pat, text)
    -- print all captures
    for i = 1, #tab do
       print("capture ", i, tab[i])
    end
]]

local ffi = require "ffi"

local ffi_new = ffi.new
local ffi_string = ffi.string
local int_array_ty = ffi.typeof("int [?]");
local char_array_ty = ffi.typeof("char [?]");


local _M = {}
local mt = { __index = _M }

ffi.cdef [[
    typedef struct {
        const char* str;
        int len;
    } RE2C_capture_t;

    struct re2_pattern_t;

    struct re2_pattern_t* re2c_compile(const char* pattern, int pat_len,
                                       int* submatch_num,
                                       char* errstr, int errstrlen,
                                       const char* re2_options, int max_mem);
    void re2c_free(struct re2_pattern_t*);
    int re2c_getncap(struct re2_pattern_t*);

    int re2c_match(const char* text, int text_len, struct re2_pattern_t*);
    int re2c_matchn(const char* text, int text_len, struct re2_pattern_t* pattern,
                    RE2C_capture_t*, int capture_num);
    size_t strlen(const char *s);
]]

local cap_array_ty = ffi.typeof("RE2C_capture_t [?]");
local re2_c_lib = ffi.load("libre2c.so")
local re2c_compile = re2_c_lib.re2c_compile
local re2c_match = re2_c_lib.re2c_match
local re2c_matchn = re2_c_lib.re2c_matchn
local re2c_getncap = re2_c_lib.re2c_getncap

function _M.new(max_cap)
    local cap_num = max_cap or 40

    local self = {
        capture_buf = ffi_new(cap_array_ty, cap_num),
        ncap = cap_num,
    }

    return setmetatable(self, mt)
end

-- Compile the given pattern, it will return three variables
--   o. the precompiled pattern or nil,
--   o. the number of capture the pattern has,
--   o. error message in case it was not successful.
--
--   The "options" is a string, each char being a single-char option. See
-- re2_c.h for the list of options and their definition.
--
-- "max_mem" is another option for RE2. Again see re2_c.h for its definition.
--
-- Both "options" and "max_mem" could be nil.
--
local function compile(pattern, options, max_mem)
    local max_mem = max_mem or 0
    local err_str_sz = 100
    local err_udata = ffi_new(char_array_ty, err_str_sz)

    local pat = re2c_compile(pattern, #pattern, nil, err_udata,
                             err_str_sz, options, max_mem)
    if pat == nil then
        -- NOTE: "pat == nil" and "not pat" are not equivalent in this case!
        local err = ffi_string(err_udata) --, ffi.C.strlen(err_udata))
        return nil, nil, err
    end

    ffi.gc(pat, re2c_free)

    return pat, re2c_getncap(pat), nil
end
_M.compile = compile

-- Peform pattern match, return non-nil if successful, or nil otherwise.
-- The pattern may have capture, but this function does not return thoese
-- captpures back to the caller (hence "_nocap").
local function match_nocap(pattern, text)
    ret = re2c_match(text, #text, pattern)
    if ret == 0 then
        return 1
    end
end
_M.match_nocap = match_nocap

-- Peform pattern match; it returns three variables
--  o. non-nil if matches, nil otherwise,
--  o. the capture(s),
--  o. error message if it doesn't match, or nil otherwise.
--
--  The paramater cap_idx can take following values:
--   o. 0 or nil: do not return captures if any
--   o. -1 : all the captures, in this case, the 2nd return is a table
--                 containing all the captures.
--   o. 1 to <the-number-of-cap>: particular capture.
--
local function match(self, pattern, text, cap_idx)
    local cap_idx = cap_idx or 0
    local ncap = re2c_getncap(pattern);
    if ncap < cap_idx or cap_idx < -1 or cap_idx > self.ncap then
        return nil, nil, "capture index out of range"
    end

    if ncap == 0 or cap_idx == 0 then
        local ret = re2c_match(text, #text, pattern)
        return ret and 1 or nil
    end

    local cap_vect = self.capture_buf
    local ret = re2c_matchn(text, #text, pattern, cap_vect, ncap)
    if ret == 0 then
        if cap_idx == -1 then
            -- return all captures in an array
            local cap_array = {}
            for i = 1, ncap do
                cap_array[i] = ffi_string(cap_vect[i-1].str, cap_vect[i-1].len)
            end
            return 1, cap_array
        else
            -- return particular capture as a string
            local cap = ffi_string(cap_vect[cap_idx-1].str,
                                  cap_vect[cap_idx-1].len)
            return 1, cap
        end
    end
end
_M.match = match

return _M
