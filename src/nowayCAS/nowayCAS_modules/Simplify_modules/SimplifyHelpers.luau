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

-- Powers two numeric nodes.
function SimplifyHelpers.pow(a, b)
	local a_num, a_den = Util.toRational(a)
	local b_num, b_den = Util.toRational(b)

	-- Undefined: 0^0
	if a_num == 0 and b_num == 0 then
		return nil
	end

	-- If base < 0, exponent must be an integer
	if a_num < 0 and b_den ~= 1 then
		return nil
	end

	-- If exponent is not an integer, result is rational only if:
	--   base is a perfect k-th power
	if b_den ~= 1 then
		-- fractional exponent: n^(p/q)
		local p = b_num
		local q = b_den

		-- Check if base is a perfect q-th power
		local base = a_num / a_den
		if base <= 0 then
			return nil
		end

		local root = base^(1/q)
		if root % 1 ~= 0 then
			return nil
		end

		-- Now compute (root^p)
		local result = root^p
		return Util.fromRational(result, 1)
	end

	-- Integer exponent: always rational
	local exp = b_num
	local base = a_num / a_den
	local result = base ^ exp

	-- Convert integer or rational result back
	return Util.fromRational(result, 1)
end

return SimplifyHelpers