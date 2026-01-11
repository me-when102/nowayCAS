local SimplifyHelpers = {}

local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)

-- Check if a node is numeric (num or rat)
function SimplifyHelpers.isNumeric(n)
	return n.kind == "num" or n.kind == "rat"
end

-- Convert Node.Num or Node.Rat -> (num, den)
function SimplifyHelpers.toRational(n)
	if n.kind == "num" then
		return tonumber(n.value), 1
	elseif n.kind == "rat" then
		return n.num, n.den
	end
end

-- Convert rational pair -> Node.Num or Node.Rat
function SimplifyHelpers.fromRational(num, den)
	-- reduce
	local g = Util.gcd(num, den)
	num = num // g
	den = den // g

	if den == 1 then
		return Node.Num(tostring(num))
	end

	return Node.Rat(num, den)
end

-- Value Helpers

-- Returns true if the node is zero.
function SimplifyHelpers.isZero(n)
	if n.kind == "num" then
		return n.value == "0"
	elseif n.kind == "rat" then
		return n.num == 0
	end
	return false
end

-- Returns true if the node is negative one.
function SimplifyHelpers.isNegOne(n)
	if n.kind == "num" then
		return n.value == "-1"
	elseif n.kind == "rat" then
		return n.num == -1 and n.den == 1
	end
	return false
end

-- Returns true if the node is one.
function SimplifyHelpers.isOne(n)
	if n.kind == "num" then
		return n.value == "1"
	elseif n.kind == "rat" then
		return n.num == 1 and n.den == 1
	end
	return false
end

-- Returns true if the node is true.
function SimplifyHelpers.isTrue(n)
	return n.kind == "const" and n.name == "true"
end

-- Returns true if the node is false.
function SimplifyHelpers.isFalse(n)
	return n.kind == "const" and n.name == "false"
end

----------------------------------------------------------------------
-- Rational arithmetic
----------------------------------------------------------------------

-- Adds two numeric nodes.
function SimplifyHelpers.add(a, b)
	local a_num, a_den = SimplifyHelpers.toRational(a)
	local b_num, b_den = SimplifyHelpers.toRational(b)
	return SimplifyHelpers.fromRational(
		a_num * b_den + b_num * a_den,
		a_den * b_den
	)
end

-- Subtracts two numeric nodes.
function SimplifyHelpers.sub(a, b)
	local a_num, a_den = SimplifyHelpers.toRational(a)
	local b_num, b_den = SimplifyHelpers.toRational(b)
	return SimplifyHelpers.fromRational(
		a_num * b_den - b_num * a_den,
		a_den * b_den
	)
end

-- Multiplies two numeric nodes.
function SimplifyHelpers.mul(a, b)
	local a_num, a_den = SimplifyHelpers.toRational(a)
	local b_num, b_den = SimplifyHelpers.toRational(b)
	return SimplifyHelpers.fromRational(
		a_num * b_num,
		a_den * b_den
	)
end

-- Divides two numeric nodes.
function SimplifyHelpers.div(a, b)
	local a_num, a_den = SimplifyHelpers.toRational(a)
	local b_num, b_den = SimplifyHelpers.toRational(b)
	return SimplifyHelpers.fromRational(
		a_num * b_den,
		a_den * b_num
	)
end

return SimplifyHelpers