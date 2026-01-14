local AlgebraicCanon = {}

local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)
local CanonAlgebraHelpers = require(script.Parent.CanonAlgebraHelpers)
local CanonHelpers = require(script.Parent.CanonHelpers)

-- Canonicalizes the node algebraically.
function AlgebraicCanon.normalize(node)
	if Util.isNum(node) or Util.isVar(node) or Util.isConst(node) then
		return node
	end

	if Util.isFunc(node) then
		return AlgebraicCanon.normalizeFunc(node)

	elseif Util.isComplex(node) then
		return AlgebraicCanon.normalizeComplex(node)

	elseif Util.isOp(node) then
		return AlgebraicCanon.normalizeOp(node)

	elseif Util.isRat(node) then
		return AlgebraicCanon.normalizeRat(node)

	elseif Util.isPiecewise(node) then
		return AlgebraicCanon.normalizePiecewise(node)

	end

	error("AlgebraicCanon: unknown node kind '" .. tostring(node.kind) .. "'")
end

-- Canonicalizes the operator node.
function AlgebraicCanon.normalizeOp(node)
	local op = node.op
	local left = AlgebraicCanon.normalize(node.left)
	local right = AlgebraicCanon.normalize(node.right)

	-- SUBTRACTION: a - b -> a + (-1 * b)
	if op == "-" then
		return AlgebraicCanon.normalize(
			Node.Op("+", left, Node.Op("*", Node.Num("-1"), right))
		)
	end

	-- ADDITION
	if op == "+" then
		local items = CanonAlgebraHelpers.flatten("+", { left, right })
		for i, n in ipairs(items) do
			items[i] = AlgebraicCanon.normalize(n)
		end
		items = CanonAlgebraHelpers.combineAdd(items)
		items = CanonAlgebraHelpers.combineLikeTerms(items)
		return Node.Op("+", items[1], items[2] or Node.Num("0"))
	end

	-- MULTIPLICATION
	if op == "*" then
		local items = CanonAlgebraHelpers.flatten("*", { left, right })
		for i, n in ipairs(items) do
			items[i] = AlgebraicCanon.normalize(n)
		end
		items = CanonAlgebraHelpers.combineMul(items)
		return Node.Op("*", items[1], items[2] or Node.Num("1"))
	end

	-- DIVISION (rational creation)
	if op == "/" then
		if Util.isOne(right) then return left end

		if Util.isNum(left) and Util.isNum(right) then
			return Node.Rat(tonumber(left.value), tonumber(right.value))
		end

		if Util.isRat(left) and Util.isNum(right) then
			return Node.Rat(left.num, left.den * tonumber(right.value))
		end

		if Util.isNum(left) and Util.isRat(right) then
			return Node.Rat(tonumber(left.value) * right.den, right.num)
		end

		if Util.isRat(left) and Util.isRat(right) then
			return Node.Rat(left.num * right.den, left.den * right.num)
		end

		return Node.Op("/", left, right)
	end

	-- EXPONENTIATION
	if op == "^" then
		return Node.Op("^", left, right)
	end

	-- COMPARISONS
	if op == ">" or op == "<" or op == ">=" or op == "<=" or op == "==" or op == "!=" then
		return Node.Op(op, left, right)
	end

	-- LOGICAL
	if op == "and" or op == "or" then
		return Node.Op(op, left, right)
	end
	
	error("AlgebraicCanon.normalizeOp: Unknown operator '".. op .. "'.")
end

-- Normalizes the function node algebraically.
function AlgebraicCanon.normalizeFunc(node)
	-- AlgebraicCanon does not modify functions
	-- except canonicalizing children algebraically
	local newArgs = {}
	for i, a in ipairs(node.args) do
		newArgs[i] = AlgebraicCanon.normalize(a)
	end

	return Node.Func(node.name, newArgs)
end

-- Normalizes the complex node algebraically.
function AlgebraicCanon.normalizeComplex(node)
	local real = AlgebraicCanon.normalize(node.real)
	local imag = AlgebraicCanon.normalize(node.imag)

	-- 0 + 0i -> 0
	if Util.isZero(real) and Util.isZero(imag) then
		return Node.Num("0")
	end

	-- a + 0i -> a
	if Util.isZero(imag) then
		return real
	end

	-- 0 + bi -> b * i
	if Util.isZero(real) then
		return Node.Op("*", imag, Node.Const("i"))
	end

	-- Otherwise keep as complex
	return Node.Complex(real, imag)
end

-- Normalizes the rational node algebraically.
function AlgebraicCanon.normalizeRat(node)
	local n = node.num
	local d = node.den

	-- Zero numerator -> 0
	if n == 0 then
		return Node.Num("0")
	end

	-- Normalize sign: denominator always positive
	if d < 0 then
		n = -n
		d = -d
	end

	-- Reduce by gcd
	local g = Util.gcd(math.abs(n), d)
	if g ~= 1 then
		n = n // g
		d = d // g
	end

	-- Collapse integers
	if d == 1 then
		return Node.Num(tostring(n))
	end

	return Node.Rat(n, d)
end

-- Normalizes the piecewise node algebraically.
function AlgebraicCanon.normalizePiecewise(node)
	local newBranches = {}

	for _, pair in ipairs(node.branches) do
		local cond = AlgebraicCanon.normalize(pair[1])
		local expr = AlgebraicCanon.normalize(pair[2])
		table.insert(newBranches, { cond, expr })
	end

	return Node.Piecewise(newBranches)
end

return AlgebraicCanon