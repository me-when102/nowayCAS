local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- sec(0) = 1
	-- csc(0) = undefined (leave alone)
	-- cot(0) = undefined (leave alone)
	----------------------------------------------------------------------
	function(name, x)
		if Util.isZero(x) then
			if name == "sec" then
				return Node.Num("1")
			end
		end
	end,

	----------------------------------------------------------------------
	-- Odd/even symmetry
	-- sec(-x) = sec(x)
	-- csc(-x) = -csc(x)
	-- cot(-x) = -cot(x)
	----------------------------------------------------------------------
	function(name, x)
		if Util.isOp(x) and x.op == "*" and Util.isNegOne(x.left) then
			local inner = x.right

			if name == "sec" then
				return Node.Func("sec", { inner })
			end

			if name == "csc" then
				return Node.Op("*", Node.Num("-1"), Node.Func("csc", { inner }))
			end

			if name == "cot" then
				return Node.Op("*", Node.Num("-1"), Node.Func("cot", { inner }))
			end
		end
	end,
}