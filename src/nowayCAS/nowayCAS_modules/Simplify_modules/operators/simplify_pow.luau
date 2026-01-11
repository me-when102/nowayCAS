local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- x ^ 1 -> x
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isOne(b) then
			return a
		end
	end,

	----------------------------------------------------------------------
	-- x ^ 0 -> 1
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isZero(b) then
			return Node.Num("1")
		end
	end,

	----------------------------------------------------------------------
	-- x ^ (-1) -> 1 / x
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isNegOne(b) then
			return Node.Op("/", Node.Num("1"), a)
		end
	end,

	----------------------------------------------------------------------
	-- (x^a)^b -> x^(a*b)
	-- Only when a and b are numeric (num or rat)
	----------------------------------------------------------------------
	function(a, b)
		if a.kind == "op" and a.op == "^"
			and SimplifyHelpers.isNumeric(a.right)
			and SimplifyHelpers.isNumeric(b) then

			local a_num, a_den = SimplifyHelpers.toRational(a.right)
			local b_num, b_den = SimplifyHelpers.toRational(b)

			-- Only fold integer exponents: denominator must be 1
			if a_den == 1 and b_den == 1 then
				local newExp = a_num * b_num
				return Node.Op("^", a.left, Node.Num(tostring(newExp)))
			end
		end
	end,
}