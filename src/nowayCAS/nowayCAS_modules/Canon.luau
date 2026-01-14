local Canon = {}
local CANON_CACHE = {}

local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)

local CanonStruct = require(script.CanonStruct)
local CanonHelpers = require(script.CanonHelpers)

local table_insert = table.insert
local table_sort = table.sort
local ipairs = ipairs

-------------------------------------------------------
-- Structural Canonicalization
-- Maintains structurability to AST nodes.
-------------------------------------------------------

-- Canonicalizes the node.
function Canon.canonical(node)
	local cached = CANON_CACHE[node]
	if cached then
		return cached
	end

	local result

	if Util.isNum(node) or Util.isVar(node) or Util.isConst(node) then
		result = node

	elseif Util.isFunc(node) then
		result = Canon._canonicalFunc(node)

	elseif Util.isComplex(node) then
		result = Canon._canonicalComplex(node)

	elseif Util.isOp(node) then
		result = Canon._canonicalOp(node)

	elseif Util.isRat(node) then
		result = Canon._canonicalRat(node)

	elseif Util.isPiecewise(node) then
		result = Canon._canonicalPiecewise(node)

	else
		error("Canonical: unknown node kind '" .. tostring(node.kind) .. "'")
	end

	CANON_CACHE[node] = result
	return result
end

-------------------------------------------------------
-- Functions
-------------------------------------------------------

-- Canonicalizes the function nodes.
function Canon._canonicalFunc(node)
	local newArgs = {}
	for i, a in ipairs(node.args) do
		newArgs[i] = Canon.canonical(a)
	end

	return Node.Func(node.name, newArgs)
end

-------------------------------------------------------
-- Operators
-------------------------------------------------------

-- Canonicalizers the operator nodes.
function Canon._canonicalOp(node)
	local op = node.op
	local left = Canon.canonical(node.left)
	local right = Canon.canonical(node.right)

	-------------------------------------------------------
	-- ADDITION (structural flatten + sort)
	-------------------------------------------------------
	if op == "+" then
		local items = CanonStruct.flatten("+", { left, right })

		table_sort(items, function(a, b)
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		if #items == 0 then return Node.Num("0") end
		if #items == 1 then return items[1] end

		local acc = items[1]
		for i = 2, #items do
			acc = Node.Op("+", acc, items[i])
		end
		return acc
	end

	-------------------------------------------------------
	-- MULTIPLICATION (structural flatten + sort)
	-------------------------------------------------------
	if op == "*" then
		local items = CanonStruct.flatten("*", { left, right })

		table_sort(items, function(a, b)
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		if #items == 1 then return items[1] end

		local acc = items[1]
		for i = 2, #items do
			acc = Node.Op("*", acc, items[i])
		end
		return acc
	end

	-------------------------------------------------------
	-- SUBTRACTION (structural only)
	-------------------------------------------------------
	if op == "-" then
		return Node.Op("-", left, right)
	end

	-------------------------------------------------------
	-- EXPONENTIATION (structural only)
	-------------------------------------------------------
	if op == "^" then
		return Node.Op("^", left, right)
	end

	-------------------------------------------------------
	-- DIVISION (structural only)
	-------------------------------------------------------
	if op == "/" then
		return Node.Op("/", left, right)
	end

	-------------------------------------------------------
	-- COMPARISON OPERATORS
	-------------------------------------------------------
	if op == ">" or op == "<" or op == ">=" or op == "<=" or op == "==" or op == "!=" then
		return Node.Op(op, left, right)
	end

	-------------------------------------------------------
	-- LOGICAL OPERATORS (flatten + dedupe + sort)
	-------------------------------------------------------
	if op == "and" or op == "or" then
		local items = CanonStruct.flatten(op, { left, right })

		local seen = {}
		local unique = {}
		for _, n in ipairs(items) do
			local key = CanonHelpers.canonicalKey(n)
			if not seen[key] then
				seen[key] = true
				table_insert(unique, n)
			end
		end

		table_sort(unique, function(a, b)
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		if #unique == 1 then return unique[1] end

		local acc = unique[1]
		for i = 2, #unique do
			acc = Node.Op(op, acc, unique[i])
		end

		return acc
	end
end

-------------------------------------------------------
-- Complex Numbers
-------------------------------------------------------

-- Canonicalizes the complex nodes.
function Canon._canonicalComplex(node)
	local real = Canon.canonical(node.real)
	local imag = Canon.canonical(node.imag)

	if Util.isZero(real) and Util.isZero(imag) then
		return Node.Num("0")
	end

	if Util.isZero(imag) then
		return real
	end

	if Util.isZero(real) then
		return Node.Op("*", imag, Node.Const("i"))
	end

	return Node.Complex(real, imag)
end

-------------------------------------------------------
-- Rational Numbers
-------------------------------------------------------

-- Canonicalizes the rational nodes.
function Canon._canonicalRat(node)
	local n = node.num
	local d = node.den

	if n == 0 then
		return Node.Num("0")
	end

	if d < 0 then
		n = -n
		d = -d
	end

	local g = Util.gcd(math.abs(n), d)
	if g ~= 1 then
		n = n // g
		d = d // g
	end

	if d == 1 then
		return Node.Num(tostring(n))
	end

	return Node.Rat(n, d)
end

-------------------------------------------------------
-- Piecewise
-------------------------------------------------------

-- Canonicalizes the piecewise nodes.
function Canon._canonicalPiecewise(node)
	local newBranches = {}

	for _, pair in ipairs(node.branches) do
		local cond = Canon.canonical(pair[1])
		local expr = Canon.canonical(pair[2])
		table_insert(newBranches, { cond, expr })
	end

	return Node.Piecewise(newBranches)
end

-- The Canonicalizer sub-library.
return Canon