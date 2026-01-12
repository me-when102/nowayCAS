local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- x ^ 1 -> x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOne(b) then
			return a
		end
	end,

	----------------------------------------------------------------------
	-- x ^ 0 -> 1
	----------------------------------------------------------------------
	function(a, b)
		if Util.isZero(b) then
			return Node.Num("1")
		end
	end,

	----------------------------------------------------------------------
	-- x ^ (-1) -> 1 / x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(b) then
			return Node.Op("/", Node.Num("1"), a)
		end
	end,

	----------------------------------------------------------------------
	-- (x^a)^b -> x^(a*b)
	-- Only when a and b are numeric (num or rat)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(a) and a.op == "^"
			and Util.isNumeric(a.right)
			and Util.isNumeric(b) then

			local a_num, a_den = Util.toRational(a.right)
			local b_num, b_den = Util.toRational(b)

			-- Only fold integer exponents: denominator must be 1
			if a_den == 1 and b_den == 1 then
				local newExp = a_num * b_num
				return Node.Op("^", a.left, Node.Num(tostring(newExp)))
			end
		end
	end,
}