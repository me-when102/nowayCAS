local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)
local Assume = require(script.Parent.Parent.Parent.Assume)

return {

	----------------------------------------------------------------------
	-- sqrt(0) -> 0
	-- abs(0)  -> 0
	-- floor(0) -> 0
	-- ceil(0)  -> 0
	-- sign(0)  -> 0
	-- factorial(0) -> 1
	----------------------------------------------------------------------
	function(name, x)
		if Util.isZero(x) then
			if name == "sqrt"      then return Node.Num("0") end
			if name == "abs"       then return Node.Num("0") end
			if name == "floor"     then return Node.Num("0") end
			if name == "ceil"      then return Node.Num("0") end
			if name == "sign"      then return Node.Num("0") end
			if name == "factorial" then return Node.Num("1") end
		end
	end,

	----------------------------------------------------------------------
	-- sqrt(x^2) -> x or -x or abs(x)
	-- Only applies when exponent is exactly 2.
	----------------------------------------------------------------------
	function(name, x)
		if name ~= "sqrt" then return end

		-- match x^2
		if Util.isOp(x) and x.op == "^"
			and Util.isTwo(x.right)
		then
			local base = x.left

			-- Only variables get assumption-based simplification
			if Util.isVar(base) then
				if Assume.is(base, "positive") then
					return base
				elseif Assume.is(base, "negative") then
					return Node.Op("*", Node.Num("-1"), base)
				else
					return Node.Func("abs", { base })
				end
			end
		end
	end,

	----------------------------------------------------------------------
	-- abs(-x)  -> abs(x)
	-- sign(-x) -> -sign(x)
	-- sqrt(-x), floor(-x), ceil(-x), factorial(-x) -> no simplification
	----------------------------------------------------------------------
	function(name, x)
		-- match -1 * inner
		if Util.isOp(x) and x.op == "*" and Util.isNegOne(x.left) then
			local inner = x.right

			if name == "abs" then
				return Node.Func("abs", { inner })
			end

			if name == "sign" then
				return Node.Op("*", Node.Num("-1"), Node.Func("sign", { inner }))
			end

			-- Other functions do not simplify negative arguments
		end
	end,

	----------------------------------------------------------------------
	-- factorial(n) for small integer constants
	-- Only structural: do NOT evaluate large factorials.
	-- Allowed: 0! = 1, 1! = 1
	----------------------------------------------------------------------
	function(name, x)
		if name ~= "factorial" then return end

		if Util.isOne(x) then
			return Node.Num("1")
		end
		
		-- 0! handled in the zero rule above
	end,
}