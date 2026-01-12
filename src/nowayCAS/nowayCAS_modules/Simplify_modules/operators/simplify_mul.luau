local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- identity: x * 1 -> x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOne(b) then
			return a
		end
	end,

	function(a, b)
		if Util.isOne(a) then
			return b
		end
	end,

	----------------------------------------------------------------------
	-- annihilator: x * 0 -> 0
	----------------------------------------------------------------------
	function(a, b)
		if Util.isZero(b) then
			return Node.Num("0")
		end
	end,

	function(a, b)
		if Util.isZero(a) then
			return Node.Num("0")
		end
	end,

	----------------------------------------------------------------------
	-- negation patterns
	-- (-1) * (-1) -> 1
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(a) and Util.isNegOne(b) then
			return Node.Num("1")
		end
	end,

	----------------------------------------------------------------------
	-- (-1) * x -> -x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(a) then
			return Node.Op("*", Node.Num("-1"), b)
		end
	end,

	----------------------------------------------------------------------
	-- x * (-1) -> -x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(b) then
			return Node.Op("*", Node.Num("-1"), a)
		end
	end,

	----------------------------------------------------------------------
	-- -(-x) -> x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(a)
			and Util.isOp(b) and b.op == "*"
			and Util.isNegOne(b.left) then
			return b.right
		end
	end,

	----------------------------------------------------------------------
	-- (-1) * (u / v) -> -(u / v)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(a)
			and Util.isOp(b) and b.op == "/" then
			return Node.Op("*", Node.Num("-1"), b)
		end
	end,

	----------------------------------------------------------------------
	-- (u / v) * (-1) -> -(u / v)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(b)
			and Util.isOp(a) and a.op == "/" then
			return Node.Op("*", Node.Num("-1"), a)
		end
	end,

	----------------------------------------------------------------------
	-- (-1) * (u * v) -> -(u * v)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(a)
			and Util.isOp(b) and b.op == "*" then
			return Node.Op("*", Node.Num("-1"), b)
		end
	end,

	----------------------------------------------------------------------
	-- (u * v) * (-1) -> -(u * v)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(b)
			and Util.isOp(a) and a.op == "*" then
			return Node.Op("*", Node.Num("-1"), a)
		end
	end,

	----------------------------------------------------------------------
	-- Flatten right: x * (y * z) -> (x * y * z)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(b) and b.op == "*" then
			return Node.Op("*",
				Node.Op("*", a, b.left),
				b.right
			)
		end
	end,

	----------------------------------------------------------------------
	-- Flatten left: (x * y) * z -> (x * y * z)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(a) and a.op == "*" then
			return Node.Op("*",
				a.left,
				Node.Op("*", a.right, b)
			)
		end
	end,

	----------------------------------------------------------------------
	-- Combine numeric factors: (a * b) * c -> Num(a*b*c)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(a) and a.op == "*"
			and Util.isNumeric(a.left)
			and Util.isNumeric(a.right)
			and Util.isNumeric(b) then

			local ab = SimplifyHelpers.mul(a.left, a.right)
			return SimplifyHelpers.mul(ab, b)
		end
	end,

	----------------------------------------------------------------------
	-- (x * a) * b -> x * (a*b)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(a) and a.op == "*"
			and Util.isNumeric(a.right)
			and Util.isNumeric(b) then

			local prod = SimplifyHelpers.mul(a.right, b)
			return Node.Op("*", a.left, prod)
		end
	end,

	----------------------------------------------------------------------
	-- 1/x * x -> 1
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(a) and a.op == "/"
			and Util.isOne(a.left)
			and Util.nodeEquals(a.right, b) then
			return Node.Num("1")
		end
	end,

	----------------------------------------------------------------------
	-- Negation propagation: (-1)*(u+v) -> (-u) + (-v)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(a)
			and Util.isOp(b) and b.op == "+" then

			local negLeft = Node.Op("*", Node.Num("-1"), b.left)
			local negRight = Node.Op("*", Node.Num("-1"), b.right)

			return Node.Op("+", negLeft, negRight)
		end
	end,

	----------------------------------------------------------------------
	-- x * i
	----------------------------------------------------------------------
	function(a, b)
		if Util.isConst(b) and b.name == "i" then
			return Node.Complex(Node.Num("0"), a)
		end
	end,

	----------------------------------------------------------------------
	-- i * x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isConst(a) and a.name == "i" then
			return Node.Complex(Node.Num("0"), b)
		end
	end,

	----------------------------------------------------------------------
	-- i * i -> -1
	----------------------------------------------------------------------
	function(a, b)
		if Util.isConst(a) and a.name == "i"
			and Util.isConst(b) and b.name == "i" then
			return Node.Num("-1")
		end
	end,

	----------------------------------------------------------------------
	-- (a + bi) * (c + di)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isComplex(a) and Util.isComplex(b) then
			local ac = Node.Op("*", a.real, b.real)
			local bd = Node.Op("*", a.imag, b.imag)
			local ad = Node.Op("*", a.real, b.imag)
			local bc = Node.Op("*", a.imag, b.real)

			return Node.Complex(
				Node.Op("-", ac, bd),
				Node.Op("+", ad, bc)
			)
		end
	end,
}