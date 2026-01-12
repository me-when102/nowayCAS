local SimplifyHelpers = {}

local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)

----------------------------------------------------------------------
-- Rational arithmetic
----------------------------------------------------------------------

-- Adds two numeric nodes.
function SimplifyHelpers.add(a, b)
	local a_num, a_den = Util.toRational(a)
	local b_num, b_den = Util.toRational(b)
	return Util.fromRational(
		a_num * b_den + b_num * a_den,
		a_den * b_den
	)
end

-- Subtracts two numeric nodes.
function SimplifyHelpers.sub(a, b)
	local a_num, a_den = Util.toRational(a)
	local b_num, b_den = Util.toRational(b)
	return Util.fromRational(
		a_num * b_den - b_num * a_den,
		a_den * b_den
	)
end

-- Multiplies two numeric nodes.
function SimplifyHelpers.mul(a, b)
	local a_num, a_den = Util.toRational(a)
	local b_num, b_den = Util.toRational(b)
	return Util.fromRational(
		a_num * b_num,
		a_den * b_den
	)
end

-- Divides two numeric nodes.
function SimplifyHelpers.div(a, b)
	local a_num, a_den = Util.toRational(a)
	local b_num, b_den = Util.toRational(b)
	return Util.fromRational(
		a_num * b_den,
		a_den * b_num
	)
end

return SimplifyHelpers