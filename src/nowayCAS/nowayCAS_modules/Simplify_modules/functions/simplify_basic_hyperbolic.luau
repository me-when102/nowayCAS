local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- sinh(0) -> 0
	-- cosh(0) -> 1
	-- tanh(0) -> 0
	----------------------------------------------------------------------
	function(name, x)
		if Util.isZero(x) then
			if name == "sinh" then return Node.Num("0") end
			if name == "cosh" then return Node.Num("1") end
			if name == "tanh" then return Node.Num("0") end
		end
	end,

	----------------------------------------------------------------------
	-- sinh(-x) -> -sinh(x)
	-- cosh(-x) -> cosh(x)
	-- tanh(-x) -> -tanh(x)
	----------------------------------------------------------------------
	function(name, x)
		-- matches: -1 * inner
		if Util.isOp(x) and x.op == "*" and Util.isNegOne(x.left) then
			local inner = x.right

			if name == "sinh" then
				return Node.Op("*", Node.Num("-1"), Node.Func("sinh", { inner }))
			end

			if name == "cosh" then
				return Node.Func("cosh", { inner })
			end

			if name == "tanh" then
				return Node.Op("*", Node.Num("-1"), Node.Func("tanh", { inner }))
			end
		end
	end,
}