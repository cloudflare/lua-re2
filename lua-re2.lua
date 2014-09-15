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
    o. new():
        Create an instance of this module.

    o. compile(pattern, options, max_mem):
        Compile the pattern string. Return pre-compiled pattern on success,
        or nil otherwise.

    o. match(self, pattern, text, cap_idx)
        Match the pattern agaist the text. Return non-nil along with the
      specified capture(s). See the comment to this function for details.

    o. find((pattern, text)
        Performing matching without returning captures.

   Usage example:
   --------------

    local re2 = require "lua-re2"
    local inst = re2.new()
    local pat = re2_inst.compile("the-pattern-string")
    local caps, errmsg = re2_inst.match(pat, text)
    -- print all captures
    if caps then
        for i = 1, #caps do
            print("capture ", i, caps[i])
        end
    end
]]

local ffi = require "ffi"

local _M = {}
local mt = { __index = _M }

ffi.cdef [[
    struct re2_pattern_t;
    struct re2c_match_aux;
    struct re2_pattern_t* re2c_compile(const char* pattern, int pat_len,
                                       const char* re2_options,
                                       char* errstr,  int errstrlen,
                                       unsigned max_mem);
    void re2c_free(struct re2_pattern_t*);
    int re2c_getncap(struct re2_pattern_t*);

    int re2c_match(const char* text, int text_len, struct re2_pattern_t*,
                  struct re2c_match_aux*);
    int re2c_find(const char* text, int text_len, struct re2_pattern_t*);

    const char* re2c_get_capture(struct re2c_match_aux*, unsigned idx);
    unsigned re2c_get_capture_len(struct re2c_match_aux*, unsigned idx);

    struct re2c_match_aux* re2c_alloc_aux(void);
    void re2c_free_aux(struct re2c_match_aux*);

    const char* re2c_get_errstr(struct re2c_match_aux*);

    void* malloc(size_t);
    void free(void*);
]]

local ffi_string = ffi.string
local ffi_malloc = ffi.C.malloc
local ffi_free = ffi.C.free
local ffi_cast = ffi.cast
local ffi_gc = ffi.gc

local char_ptr_ty = ffi.typeof("char*");

-- NOTE: re2_c_lib must be referenced by a function, or is assigned to
--    _M.whatever; otherwise, the shared object would be unloaded by Garbage-
--    Collector.
--
local re2_c_lib = ffi.load("libre2c.so")
_M.re2_c_lib = re2_c_lib
local re2c_compile = re2_c_lib.re2c_compile
local re2c_match = re2_c_lib.re2c_match
local re2c_find = re2_c_lib.re2c_find
local re2c_getncap = re2_c_lib.re2c_getncap
local re2c_free = re2_c_lib.re2c_free
local re2c_get_capture = re2_c_lib.re2c_get_capture
local re2c_get_capture_len = re2_c_lib.re2c_get_capture_len

function _M.new()
    local aux = ffi_gc(re2_c_lib.re2c_alloc_aux(),
                       re2_c_lib.re2c_free_aux)

    local self = {
        aux = aux
    }

    return setmetatable(self, mt)
end

-- Compile the given pattern, it will return two values:
--   o. the precompiled pattern or nil,
--   o. error message in case it was not successful.
--
--   The "options" is a string, each char being a single-char option. See
-- re2_c.h for the list of options and their definition.
--
--   max_mem is to specify the limit of memory allocated by RE2 engine.
--
--   Both "options" and "max_mem" could be nil.
--
function _M.compile(pattern, options, max_mem)
    local buf_len = 128
    local char_buf = ffi_malloc(buf_len)
    char_bur = ffi_cast(char_ptr_ty, char_buf)

    local max_mem = max_mem or 0
    local ptn = re2c_compile(pattern, #pattern, options, char_buf, buf_len,
                             max_mem)

    if ptn == nil then
        -- NOTE: "pat == nil" and "not pat" are not equivalent in this case!
        local err = ffi_string(char_buf)
        ffi_free(char_buf)
        return nil, err
    end

    ffi_free(char_buf)
    return ffi_gc(ptn, re2c_free);
end

-- Peform pattern match. It returns two values:
--
--  o. nil if dosen't match. otherwise,
--    *) cap_idx = -1:
--      return all captures in an array where the i-th element (i>=1)
--      corresponds to i-th captures, and 0-th element is the sub-string of
--      the input text which tightly match the pattern.
--
--      e.g. pattern = "abc([0-1]+)([a-z]+)", text = "wtfabc012abc"
--      The first value returned by this function would be
--      {'abc012abc', '012', 'abc'}
--
--    *) cap_idx != -1:
--      return specified capture.
--
--  o. error message if something unusual took place
--
function _M.match(self, pattern, text, cap_idx)
    local cap_idx = cap_idx or -1
    local ncap = re2c_getncap(pattern)
    if ncap < cap_idx or cap_idx < -1 then
        return nil, "capture index out of range"
    end

    local aux = self.aux
    local ret = re2c_match(text, #text, pattern, aux)
    if ret == 0 then
        -- return all captures in an array
        if cap_idx == -1 then
            local cap_array = {}
            for i = 0, ncap do
                local str = re2c_get_capture(aux, i)
                local len = re2c_get_capture_len(aux, i)
                cap_array[i] = ffi_string(str, len)
            end
            return cap_array
        end

        -- return particular capture as a string
        if cap_idx >= 0 and cap_idx <= ncap then
            local str = re2c_get_capture(aux, cap_idx)
            local len = re2c_get_capture_len(aux, cap_idx)
            local cap = ffi_string(str, len)
            return cap
        end
    end
end

function _M.find(pattern, text)
    local ret = re2c_find(text, #text, pattern)
    if ret == 0 then
        return 1
    end
end

return _M
