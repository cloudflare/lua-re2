local re2 = require "re2"

local pat_str = [==[([a-zA-Z]+)\\ ([a-zA-Z]+)]==]
local text = [==[WTF\ Wtf1234]==]

local re2_inst = re2.new()

local pat = re2_inst.compile(pat_str)
if pat then
    local r = re2_inst.match_nocap(pat, text)
    print(r and "succ" or "fail")
end

if pat then
    local r, tab = re2_inst:match(pat, text)
    print(r and "succ" or "fail")
    if tab then
        for i = 1, #tab do
            print("capture ", i, tab[i])
        end
    end
end
