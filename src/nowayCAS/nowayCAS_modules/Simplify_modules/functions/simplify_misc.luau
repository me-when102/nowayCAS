local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)
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
		if SimplifyHelpers.isZero(x) then
			if name == "sqrt" then return Node.Num("0") end
			if name == "abs" then return Node.Num("0") end
			if name == "floor" then return Node.Num("0") end
			if name == "ceil" then return Node.Num("0") end
			if name == "sign" then return Node.Num("0") end
			if name == "factorial" then return Node.Num("1") end
		end
	end,

	----------------------------------------------------------------------
	-- sqrt(x^2) -> x or -x or abs(x)
	----------------------------------------------------------------------
	function(name, x)
		if name ~= "sqrt" then return end

		-- match x^2
		if x.kind == "op"
			and x.op == "^"
			and x.right.kind == "num"
			and x.right.value == "2"
		then
			local base = x.left

			-- Only variables get assumption-based simplification
			if base.kind == "var" then
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
	-- abs(-x) -> abs(x)
	-- sign(-x) -> -sign(x)
	-- sqrt(-x) -> no simplification (complex territory)
	-- floor/ceil/factorial: no negation rules
	----------------------------------------------------------------------
	function(name, x)
		-- match -1 * inner
		if x.kind == "op" and x.op == "*" and SimplifyHelpers.isNegOne(x.left) then
			local inner = x.right

			if name == "abs" then
				return Node.Func("abs", {inner})
			end

			if name == "sign" then
				return Node.Op("*", Node.Num("-1"), Node.Func("sign", {inner}))
			end

			-- sqrt(-x), floor(-x), ceil(-x), factorial(-x) -> no simplification
		end
	end,

	----------------------------------------------------------------------
	-- factorial(n) where n is a small integer constant
	-- Only structural: do NOT evaluate large factorials.
	-- Allowed: 0! = 1, 1! = 1
	----------------------------------------------------------------------
	function(name, x)
		if name ~= "factorial" then return end
		if x.kind == "num" then
			if x.value == "1" then
				return Node.Num("1")
			end
		end
	end,
}