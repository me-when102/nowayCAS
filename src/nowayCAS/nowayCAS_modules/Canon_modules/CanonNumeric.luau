local CanonNumeric = {}
local Util = require(script.Parent.Parent.Util)
local Node = require(script.Parent.Parent.Node)

local table_insert = table.insert

-- Rational Addition.
function CanonNumeric.ratAdd(a, b)
	-- a = {num, den}, b = {num, den}
	local num = a.num * b.den + b.num * a.den
	local den = a.den * b.den
	local g = Util.gcd(math.abs(num), math.abs(den))
	return { num = num // g, den = den // g }
end

-- Check if the rational is zero.
function CanonNumeric.ratIsZero(r)
	return r.num == 0
end

-- Check if the rational is one.
function CanonNumeric.ratIsOne(r)
	return r.num == r.den
end

-- Create a fresh rational accumulator for addition (num / den).
function CanonNumeric.newAddAccumulator()
	return { num = 0, den = 1 }
end

-- Create a fresh rational accumulator for multiplication (num / den).
function CanonNumeric.newMulAccumulator()
	return { num = 1, den = 1 }
end

-- Compute new numerator when adding an integer v to acc.
function CanonNumeric.accAddInteger(acc, v)
	local newNum = acc.num + v * acc.den
	return newNum
end

-- Compute intermediate numerators for adding rational n2/d2 to acc.
function CanonNumeric.accAddRational(acc, n2, d2)
	local a = acc.num * d2
	local b = n2 * acc.den
	return a, b
end

-- Commit a safe (num, den) pair into acc and reduce it.
function CanonNumeric.accCommit(acc, newNum, newDen)
	acc.num = newNum
	acc.den = newDen
	-- reduce
	local g = Util.gcd(math.abs(acc.num), math.abs(acc.den))
	acc.num = acc.num // g
	acc.den = acc.den // g
end

-- Emit accumulated rational into out and reset accumulator.
function CanonNumeric.accFlush(acc, out)
	if acc.num ~= 0 then
		if acc.den == 1 then
			table_insert(out, Node.Num(tostring(acc.num)))
		else
			table_insert(out, Node.Rat(acc.num, acc.den))
		end
	end
	acc.num, acc.den = 0, 1
end

-- Fold integer literal into acc or emit if overflow would occur.
function CanonNumeric.handleIntegerAdd(acc, n, out)
	if Util.beyondIntegerLimit(n.value) then
		table_insert(out, n)
		return
	end

	local v = tonumber(n.value)
	local newNum = CanonNumeric.accAddInteger(acc, v)

	if Util.beyondIntegerLimit(newNum) then
		CanonNumeric.accFlush(acc, out)
		table_insert(out, n)
	else
		acc.num = newNum
	end
end

-- Fold rational literal into acc or emit if overflow would occur.
function CanonNumeric.handleRationalAdd(acc, n, out)
	local n2, d2 = n.num, n.den
	local a, b = CanonNumeric.accAddRational(acc, n2, d2)

	if Util.beyondIntegerLimit(a) or Util.beyondIntegerLimit(b) then
		table_insert(out, n)
		return
	end

	local newNum = a + b
	local newDen = acc.den * d2

	if Util.beyondIntegerLimit(newNum) or Util.beyondIntegerLimit(newDen) then
		table_insert(out, n)
		return
	end

	CanonNumeric.accCommit(acc, newNum, newDen)
end

-- Fold integer literal into multiplicative accumulator or emit if overflow.
function CanonNumeric.handleIntegerMul(acc, n, others)
	if Util.beyondIntegerLimit(n.value) then
		table_insert(others, n)
		return
	end

	local v = tonumber(n.value)
	local newNum = acc.num * v

	if Util.beyondIntegerLimit(newNum) then
		table_insert(others, n)
	else
		acc.num = newNum
	end
end

-- Fold rational literal into multiplicative accumulator or emit if overflow.
function CanonNumeric.handleRationalMul(acc, n, others)
	local newNum = acc.num * n.num
	local newDen = acc.den * n.den

	if Util.beyondIntegerLimit(newNum) or Util.beyondIntegerLimit(newDen) then
		table_insert(others, n)
		return
	end

	acc.num = newNum
	acc.den = newDen

	local g = Util.gcd(math.abs(acc.num), math.abs(acc.den))
	acc.num = acc.num // g
	acc.den = acc.den // g
end

return CanonNumeric