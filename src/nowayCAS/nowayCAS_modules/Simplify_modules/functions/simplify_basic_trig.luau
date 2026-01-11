local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- sin(0) -> 0
	-- cos(0) -> 1
	-- tan(0) -> 0
	----------------------------------------------------------------------
	function(name, x)
		if SimplifyHelpers.isZero(x) then
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
		if x.kind == "op" and x.op == "*" and SimplifyHelpers.isNegOne(x.left) then
			local inner = x.right

			if name == "sin" then
				return Node.Op("*", Node.Num("-1"), Node.Func("sin", {inner}))
			end

			if name == "cos" then
				return Node.Func("cos", {inner})
			end

			if name == "tan" then
				return Node.Op("*", Node.Num("-1"), Node.Func("tan", {inner}))
			end
		end
	end,
}