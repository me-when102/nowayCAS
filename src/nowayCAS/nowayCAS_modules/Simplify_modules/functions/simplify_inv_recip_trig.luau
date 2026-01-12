local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- Constant folding (only when expression becomes shorter)
	-- asec(1) = 0
	----------------------------------------------------------------------
	function(name, x)
		-- asec(1) = 0 is the only one that strictly shortens
		if name == "asec" and Util.isOne(x) then
			return Node.Num("0")
		end
	end,

	----------------------------------------------------------------------
	-- Odd/even symmetry
	-- acsc(-x) = -acsc(x)
	-- acot(-x) = -acot(x)
	-- asec(-x) is unsafe → do NOT simplify
	----------------------------------------------------------------------
	function(name, x)
		if Util.isOp(x) and x.op == "*" and Util.isNegOne(x.left) then
			local inner = x.right

			-- acsc(-x) = -acsc(x)
			if name == "acsc" then
				return Node.Op("*", Node.Num("-1"), Node.Func("acsc", { inner }))
			end

			-- acot(-x) = -acot(x)
			if name == "acot" then
				return Node.Op("*", Node.Num("-1"), Node.Func("acot", { inner }))
			end

			-- asec(-x) identity involves pi and is unsafe -> skip
		end
	end,
}