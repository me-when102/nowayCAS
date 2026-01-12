local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- sin(0) -> 0
	-- cos(0) -> 1
	-- tan(0) -> 0
	----------------------------------------------------------------------
	function(name, x)
		if Util.isZero(x) then
			if name == "sin" then return Node.Num("0") end
			if name == "cos" then return Node.Num("1") end
			if name == "tan" then return Node.Num("0") end
		end
	end,

	----------------------------------------------------------------------
	-- sin(-x) -> -sin(x)
	-- cos(-x) -> cos(x)
	-- tan(-x) -> -tan(x)
	----------------------------------------------------------------------
	function(name, x)
		if Util.isOp(x) and x.op == "*" and Util.isNegOne(x.left) then
			local inner = x.right

			if name == "sin" then
				return Node.Op("*", Node.Num("-1"), Node.Func("sin", { inner }))
			end

			if name == "cos" then
				return Node.Func("cos", { inner })
			end

			if name == "tan" then
				return Node.Op("*", Node.Num("-1"), Node.Func("tan", { inner }))
			end
		end
	end,
}