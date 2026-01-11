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
			if a.kind == "var" and Assume.is(a, "nonzero") then
				return Node.Num("1")
			end
		end
	end,

	----------------------------------------------------------------------
	-- identity: x / 1 -> x
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isOne(b) then
			return a
		end
	end,

	----------------------------------------------------------------------
	-- annihilator: 0 / x -> 0
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isZero(a) then
			return Node.Num("0")
		end
	end,

	----------------------------------------------------------------------
	-- numeric folding: num/rat combinations
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isNumeric(a) and SimplifyHelpers.isNumeric(b) then
			return SimplifyHelpers.div(a, b)
		end
	end,

	----------------------------------------------------------------------
	-- (u * 1) / v -> u / v
	----------------------------------------------------------------------
	function(a, b)
		if a.kind == "op" and a.op == "*" then
			if SimplifyHelpers.isOne(a.right) then
				return Node.Op("/", a.left, b)
			end
			if SimplifyHelpers.isOne(a.left) then
				return Node.Op("/", a.right, b)
			end
		end
	end,

	----------------------------------------------------------------------
	-- (u * -1) / v -> -(u / v)
	----------------------------------------------------------------------
	function(a, b)
		if a.kind == "op" and a.op == "*"
			and SimplifyHelpers.isNegOne(a.right) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", a.left, b))
		end
	end,

	----------------------------------------------------------------------
	-- -(u) / v -> -(u / v)
	----------------------------------------------------------------------
	function(a, b)
		if a.kind == "op" and a.op == "*"
			and SimplifyHelpers.isNegOne(a.left) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", a.right, b))
		end
	end,

	----------------------------------------------------------------------
	-- u / -(v) -> -(u / v)
	----------------------------------------------------------------------
	function(a, b)
		if b.kind == "op" and b.op == "*"
			and SimplifyHelpers.isNegOne(b.left) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", a, b.right))
		end
	end,

	----------------------------------------------------------------------
	-- x / -y -> -(x / y)
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isNegOne(b) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", a, Node.Num("1")))
		end
	end,

	----------------------------------------------------------------------
	-- Reciprocal trig collapsing
	-- 1 / cos(x) -> sec(x)
	-- 1 / sin(x) -> csc(x)
	-- cos(x) / sin(x) -> cot(x)
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isOne(a)
			and b.kind == "func" and b.name == "cos" then
			return Node.Func("sec", {b.args[1]})
		end
	end,

	function(a, b)
		if SimplifyHelpers.isOne(a)
			and b.kind == "func" and b.name == "sin" then
			return Node.Func("csc", {b.args[1]})
		end
	end,

	function(a, b)
		if a.kind == "func" and a.name == "cos"
			and b.kind == "func" and b.name == "sin" then
			return Node.Func("cot", {a.args[1]})
		end
	end,

	----------------------------------------------------------------------
	-- Hyperbolic reciprocal collapsing
	-- 1 / cosh(x) -> sech(x)
	-- 1 / sinh(x) -> csch(x)
	-- cosh(x) / sinh(x) -> coth(x)
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isOne(a)
			and b.kind == "func" and b.name == "cosh" then
			return Node.Func("sech", {b.args[1]})
		end
	end,

	function(a, b)
		if SimplifyHelpers.isOne(a)
			and b.kind == "func" and b.name == "sinh" then
			return Node.Func("csch", {b.args[1]})
		end
	end,

	function(a, b)
		if a.kind == "func" and a.name == "cosh"
			and b.kind == "func" and b.name == "sinh" then
			return Node.Func("coth", {a.args[1]})
		end
	end,
}