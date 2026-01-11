local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- identity: 0 + x -> x
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isZero(a) then
			return b
		end
	end,

	function(a, b)
		if SimplifyHelpers.isZero(b) then
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
		if SimplifyHelpers.isNumeric(a) and SimplifyHelpers.isNumeric(b) then
			return SimplifyHelpers.add(a, b)
		end
	end,

	----------------------------------------------------------------------
	-- negation patterns
	-- x + (-1)*y -> x - y
	-- (-1)*x + y -> y - x
	----------------------------------------------------------------------
	function(a, b)
		if b.kind == "op" and b.op == "*" then
			local left, right = b.left, b.right
			if SimplifyHelpers.isNegOne(left) then
				return Node.Op("-", a, right)
			end
		end
	end,

	function(a, b)
		if a.kind == "op" and a.op == "*" then
			local left, right = a.left, a.right
			if SimplifyHelpers.isNegOne(left) then
				return Node.Op("-", b, right)
			end
		end
	end,

	----------------------------------------------------------------------
	-- complex addition
	----------------------------------------------------------------------
	function(a, b)
		if a.kind == "complex" and b.kind == "complex" then
			return Node.Complex(
				Node.Op("+", a.real, b.real),
				Node.Op("+", a.imag, b.imag)
			)
		end
	end,
}