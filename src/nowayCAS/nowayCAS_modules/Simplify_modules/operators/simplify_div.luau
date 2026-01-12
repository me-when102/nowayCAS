local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)
local Assume = require(script.Parent.Parent.Parent.Assume)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- x / x -> 1  (when x is assumed nonzero)
	----------------------------------------------------------------------
	function(a, b)
		if Util.nodeEquals(a, b) then
			if Util.isVar(a) and Assume.is(a, "nonzero") then
				return Node.Num("1")
			end
		end
	end,

	----------------------------------------------------------------------
	-- identity: x / 1 -> x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOne(b) then
			return a
		end
	end,

	----------------------------------------------------------------------
	-- annihilator: 0 / x -> 0
	----------------------------------------------------------------------
	function(a, b)
		if Util.isZero(a) then
			return Node.Num("0")
		end
	end,

	----------------------------------------------------------------------
	-- numeric folding: num/rat combinations
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNumeric(a) and Util.isNumeric(b) then
			return SimplifyHelpers.div(a, b)
		end
	end,

	----------------------------------------------------------------------
	-- (u * 1) / v -> u / v
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(a) and a.op == "*" then
			if Util.isOne(a.right) then
				return Node.Op("/", a.left, b)
			end
			if Util.isOne(a.left) then
				return Node.Op("/", a.right, b)
			end
		end
	end,

	----------------------------------------------------------------------
	-- (u * -1) / v -> -(u / v)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(a) and a.op == "*"
			and Util.isNegOne(a.right) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", a.left, b))
		end
	end,

	----------------------------------------------------------------------
	-- -(u) / v -> -(u / v)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(a) and a.op == "*"
			and Util.isNegOne(a.left) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", a.right, b))
		end
	end,

	----------------------------------------------------------------------
	-- u / -(v) -> -(u / v)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOp(b) and b.op == "*"
			and Util.isNegOne(b.left) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", a, b.right))
		end
	end,

	----------------------------------------------------------------------
	-- x / -y -> -(x / y)
	----------------------------------------------------------------------
	function(a, b)
		if Util.isNegOne(b) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", a, Node.Num("1")))
		end
	end,

	----------------------------------------------------------------------
	-- Reciprocal trig collapsing
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOne(a)
			and Util.isFunc(b) and b.name == "cos" then
			return Node.Func("sec", { b.args[1] })
		end
	end,

	function(a, b)
		if Util.isOne(a)
			and Util.isFunc(b) and b.name == "sin" then
			return Node.Func("csc", { b.args[1] })
		end
	end,

	function(a, b)
		if Util.isFunc(a) and a.name == "cos"
			and Util.isFunc(b) and b.name == "sin" then
			return Node.Func("cot", { a.args[1] })
		end
	end,

	----------------------------------------------------------------------
	-- Hyperbolic reciprocal collapsing
	----------------------------------------------------------------------
	function(a, b)
		if Util.isOne(a)
			and Util.isFunc(b) and b.name == "cosh" then
			return Node.Func("sech", { b.args[1] })
		end
	end,

	function(a, b)
		if Util.isOne(a)
			and Util.isFunc(b) and b.name == "sinh" then
			return Node.Func("csch", { b.args[1] })
		end
	end,

	function(a, b)
		if Util.isFunc(a) and a.name == "cosh"
			and Util.isFunc(b) and b.name == "sinh" then
			return Node.Func("coth", { a.args[1] })
		end
	end,
}