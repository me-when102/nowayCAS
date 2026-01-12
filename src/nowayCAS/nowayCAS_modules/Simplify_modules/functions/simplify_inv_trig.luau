local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- Constant folding for known values
	-- asin(0) = 0
	-- acos(0) = pi/2   (longer -> leave symbolic)
	-- atan(0) = 0
	----------------------------------------------------------------------
	function(name, x)
		if Util.isZero(x) then
			if name == "asin" then return Node.Num("0") end
			if name == "atan" then return Node.Num("0") end
		end
	end,

	----------------------------------------------------------------------
	-- Odd/even symmetry
	-- asin(-x) = -asin(x)
	-- acos(-x) = pi - acos(x)   (unsafe → do NOT simplify)
	-- atan(-x) = -atan(x)
	----------------------------------------------------------------------
	function(name, x)
		if Util.isOp(x) and x.op == "*" and Util.isNegOne(x.left) then
			local inner = x.right

			if name == "asin" then
				return Node.Op("*", Node.Num("-1"), Node.Func("asin", { inner }))
			end

			if name == "atan" then
				return Node.Op("*", Node.Num("-1"), Node.Func("atan", { inner }))
			end

			-- acos(-x) identity is unsafe (requires pi) and flips monotonicity, so skip it
		end
	end,
}