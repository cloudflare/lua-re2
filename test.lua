local re2 = require "lua-re2"
local string_fmt = string.format
local io_write = io.write

local pat_str
local text_str
local capture_str

local function print_result(id, r)
    io_write(string_fmt("Test %d %s\n", id, r and "succ" or "fail"));
end

-- Test match without or ignore capture. The result is supposed to be "match"
local function test_match_nocap(id, pat, compile_opt, text)
    local re2_inst = re2.new()
    local pat, capnum, err = re2_inst.compile(pat_str, compile_opt)
    local r
    if pat then
        r = re2_inst:match(pat, text)

        local r2 = re2.match_nocap(pat, text)
        if r ~= r2 then
            r = nil
        end
    end
    print_result(id, r)
    return r and 1 or nil
end

-- Test match without or ignore capture. The result is supposed to be
-- "not match".
local function test_not_match_nocap(id, pat, compile_opt, text)
    local re2_inst = re2.new()
    local pat, capnum, err = re2_inst.compile(pat_str, compile_opt)
    local r
    if pat then
        r = re2_inst:match(pat, text)
    end

    print_result(id, r)
    return r and 1 or nil
end

-- Test if the particular capture is correct.
local function test_match_cap(id, pat, compile_opt, text, cap_idx, capture)
    local re2_inst = re2.new()
    local pat, capnum, err = re2_inst.compile(pat_str, compile_opt)
    local res
    if pat then
        local r, cap = re2_inst:match(pat, text, cap_idx)
        if r and cap == capture then
            res = 1
        end
    end

    print_result(id, res)
    return res and 1 or nil
end

pat_str = [==[([a-zA-Z ]+)([0-9]*)]==]
text_str = "23456This is the source code repository for code 1234"
capture_str = "This is the source code repository for code "

test_match_cap(1, pat_str, nil, text_str, 1, capture_str)
test_match_cap(2, pat_str, nil, text_str, 2, "1234")
test_match_nocap(3, pat_str, nil, text_str)

-- test case-sensitivity
pat_str = [==[([a-z ]+)([0-9]*)]==]
test_match_cap(4, pat_str, "I", text_str, 1, capture_str)
