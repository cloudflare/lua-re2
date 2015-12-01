local re2 = require "lua-re2"
local string_fmt = string.format
local io_write = io.write

local pat_str
local text_str
local capture_str

local function print_result(id, r)
    io_write(string_fmt("Test %d %s\n", id, r and "succ" or "fail"));
end

-- Test match without or ignore capture. The result is supposed to be
-- "not match".
local function test_not_match_nocap(id, pat, compile_opt, text)
    local re2_inst = re2.new()
    local pat, err = re2_inst.compile(pat_str, compile_opt)
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
    local pat, err = re2_inst.compile(pat_str, compile_opt)

    local res
    if pat then
        local cap = re2_inst:match(pat, text, cap_idx)
        if cap and cap == capture then
            res = 1
        end
    end

    print_result(id, res)
    return res and 1 or nil
end

local function test_match_nocap(id, pat, compile_opt, text)
    local re2_inst = re2.new()
    local ptn, err = re2_inst.compile(pat_str, compile_opt)
    local res
    if ptn then
        local cap = re2_inst:match(ptn, text)
        if cap then
            res = 1
            local t = re2_inst.find(ptn, text)
            if not t then
                print("re2_inst::match() and re2_inst.find() disagree")
                res = nil
            end
        else
            local t = re2_inst.find(ptn, text)
            if t then
                print("re2_inst::match() and re2_inst.find() disagree")
            end
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

-- test multi-line support
pat_str = [[^\d*$]]
text_str =
[[abc
12345
xyz]]
test_match_nocap(3, pat_str, "m", text_str)

-- Test if the all captures are correct.
local function test_match_r_caps(id, pat, compile_opt, text, captures)
    local re2_inst = re2.new()
    local pat, err = re2_inst.compile(pat_str, compile_opt)

    local res
    if pat then
        local caps = re2_inst.match_r(re2_inst, pat, text, cap_idx)
        if caps and (#caps == #captures) then
            count = 0
            for i=1, #caps do
                if caps[i] == captures[i] then
                    count = count + 1
                end
            end
            if count == #caps then
                res = 1
            end
        end
    end

    print_result(id, res)
    return res and 1 or nil
end

pat_str = "([^&=]+)=([^&=]*)"
text_str = "k1=v1&k2=v2&&k3=v3&k4="
captures = {'k1', 'v1', 'k2', 'v2', 'k3', 'v3', 'k4', ''}
test_match_r_caps(4, pat_str, nil, text_str, captures)

