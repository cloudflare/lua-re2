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

    struct re2_pattern_t* re2c_compile(const char* pattern,
                                       int pat_len, int* submatch_num,
                                       char* errstr, int errstrlen);

    void re2c_free(struct re2_pattern_t*);
    int re2c_getncap(struct re2_pattern_t*);

    int re2c_match(const char* text, int text_len, struct re2_pattern_t*);
    int re2c_matchn(const char* text, int text_len, struct re2_pattern_t* pattern,
                    RE2C_capture_t*, int capture_num);
    size_t strlen(const char *s);
]]

local cap_array_ty = ffi.typeof("RE2C_capture_t [?]");
local re2_c_lib = ffi.load("libre2c")
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
local function compile(pattern)
    local capnum_udata = ffi_new(int_array_ty, 1);
    local err_udata = ffi_new(char_array_ty, 100)
    local pat = re2c_compile(pattern, #pattern, capnum_udata, err_udata, 100)
    if pat == nil then
        -- NOTE: "pat == nil" and "not pat" are not equivalent in this case!
        local err = ffi_string(err_udata, ffi.C.strlen(err_udata))
        return nil, nil, err
    end

    ffi.gc(pat, re2c_free)
    return pat, capnum_udata[0], nil
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

-- Peform pattern match, it turn three variables
--  o. non-nil if matches, nil otherwise,
--  o. the capture(s),
--  o. error message if it doesn't match, or nil otherwise.
--
--  The paramater cap_idx can take following values:
--   o. -1 or nil: all the captures, in this case, the 2nd return is a table
--                 containing all the captures.
--   o. 1 to <the-number-of-cap>: particular capture.
--
local function match(self, pattern, text, cap_idx)
    local ret = nil;
    local cap = nil
    local cap_idx = cap_idx or -1
    local ncap = re2c_getncap(pattern);
    if ncap < cap_idx or cap_idx < -1 or cap_idx > self.ncap then
        return nil, nil, "capture index out of range"
    end

    if ncap == 0 then
        ret = re2c_match(text, #text, pattern)
    end

    local cap_vect = self.capture_buf
    ret = re2c_matchn(text, #text, pattern, cap_vect, ncap)
    if ret == 0 then
        if cap_idx == -1 then
            local cap_array = {}
            for i = 1, ncap do
                cap_array[i] = ffi_string(cap_vect[i-1].str, cap_vect[i-1].len)
            end
            return 1, cap_array
        else
            local cap = ffi_string(cap_vect[cap_idx-1].str,
                                  cap_vect[cap_idx-1].len)
            return 1, cap
        end
    end
end
_M.match = match

return _M
