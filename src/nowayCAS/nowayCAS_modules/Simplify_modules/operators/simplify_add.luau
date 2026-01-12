local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- identity: 0 + x -> x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isZero(a) then
			return b
		end
	end,

	function(a, b)
		if Util.isZero(b) then
			return a
		end
	end,

	----------------------------------------------------------------------
	-- doubling: x + x -> 2 * x
	----------------------------------------------------------------------
	function(a, b)
		if Util.nodeEquals(a, b) then
			return Node.Op("*", Node.Num("2"), a)
		end
	end,

	----------------------------------------------------------------------
	-- numeric folding: num/rat combinations
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNumeric(a) and Util.isNumeric(b) then
			return SimplifyHelpers.add(a, b)
		end
	end,

	----------------------------------------------------------------------
	-- negation patterns
	-- x + (-1)*y -> x - y
	-- (-1)*x + y -> y - x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(b) and b.op == "*" then
			local left, right = b.left, b.right
			if Util.isNegOne(left) then
				return Node.Op("-", a, right)
			end
		end
	end,

	function(a, b)
		if Util.isOp(a) and a.op == "*" then
			local left, right = a.left, a.right
			if Util.isNegOne(left) then
				return Node.Op("-", b, right)
			end
		end
	end,

	----------------------------------------------------------------------
	-- complex addition
	----------------------------------------------------------------------
	function(a, b)
		if Util.isComplex(a) and Util.isComplex(b) then
			return Node.Complex(
				Node.Op("+", a.real, b.real),
				Node.Op("+", a.imag, b.imag)
			)
		end
	end,
}