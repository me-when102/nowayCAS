local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

    ----------------------------------------------------------------------
    -- sech(0) -> 1
    -- csch(0) -> undefined (do NOT simplify)
    -- coth(0) -> undefined (do NOT simplify)
    ----------------------------------------------------------------------
    function(name, x)
        if Util.isZero(x) then
            if name == "sech" then
                return Node.Num("1")
            end
        end
    end,

    ----------------------------------------------------------------------
    -- sech(-x) -> sech(x)
    -- csch(-x) -> -csch(x)
    -- coth(-x) -> -coth(x)
    ----------------------------------------------------------------------
    function(name, x)
        -- matches: -1 * inner
        if Util.isOp(x) and x.op == "*" and Util.isNegOne(x.left) then
            local inner = x.right

            if name == "sech" then
                return Node.Func("sech", { inner })
            end

            if name == "csch" then
                return Node.Op("*", Node.Num("-1"), Node.Func("csch", { inner }))
            end

            if name == "coth" then
                return Node.Op("*", Node.Num("-1"), Node.Func("coth", { inner }))
            end
        end
    end,
}