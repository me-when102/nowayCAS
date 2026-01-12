local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

    ----------------------------------------------------------------------
    -- asinh(0) -> 0
    -- acosh(0) -> no simplification (domain issue)
    -- atanh(0) -> 0
    ----------------------------------------------------------------------
    function(name, x)
        if Util.isZero(x) then
            if name == "asinh" then return Node.Num("0") end
            if name == "atanh" then return Node.Num("0") end
            -- acosh(0) is undefined → no simplification
        end
    end,

    ----------------------------------------------------------------------
    -- asinh(-x) -> -asinh(x)
    -- acosh(-x) -> no simplification (not even/odd)
    -- atanh(-x) -> -atanh(x)
    ----------------------------------------------------------------------
    function(name, x)
        -- matches: -1 * inner
        if Util.isOp(x) and x.op == "*" and Util.isNegOne(x.left) then
            local inner = x.right

            if name == "asinh" then
                return Node.Op("*", Node.Num("-1"), Node.Func("asinh", { inner }))
            end

            if name == "atanh" then
                return Node.Op("*", Node.Num("-1"), Node.Func("atanh", { inner }))
            end

            -- acosh(-x) has no usable symmetry
        end
    end,
}