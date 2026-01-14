local Canon = {}
local CANON_CACHE = {}

local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)
local Assume = require(script.Parent.Assume)

local CanonAlgebra = require(script.CanonAlgebra)
local CanonHelpers = require(script.CanonHelpers)

local table_insert = table.insert
local table_sort = table.sort

local ipairs = ipairs

-------------------------------------------------------
-- Canonicalizer
-- Produces a unique, normalized AST form.
-------------------------------------------------------

-- Canonicalizes a node.
function Canon.canonical(node)
	-- DAG-aware memoization
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

function Canon._canonicalFunc(node)
	-- Canonicalize each argument
	local newArgs = {}
	for i, a in ipairs(node.args) do
		newArgs[i] = Canon.canonical(a)
	end

	local name = node.name

	-------------------------------------------------------
	-- Special-case canonical rules for functions
	-------------------------------------------------------

	-- abs(x) -> x if x > 0
	if name == "abs" and #newArgs == 1 then
		local arg = newArgs[1]

		if arg.kind == "var" then
			if Assume.is(arg, "positive") then
				return arg
			elseif Assume.is(arg, "negative") then
				return Node.Op("*", Node.Num("-1"), arg)
			end
		end
	end

	if name == "not" then
		-- Unary logical negation
		return Node.Func("not", newArgs)
	end

	-------------------------------------------------------
	-- Default: rebuild function node
	-------------------------------------------------------
	return Node.Func(name, newArgs)
end

-- Canonicalizes the operator
function Canon._canonicalOp(node)
	local op = node.op
	local left = Canon.canonical(node.left)
	local right = Canon.canonical(node.right)

	-------------------------------------------------------
	-- ADDITION
	-------------------------------------------------------
	if op == "+" then
		local items = CanonAlgebra.flatten("+", { left, right })
		for i,n in ipairs(items) do items[i] = Canon.canonical(n) end

		items = CanonAlgebra.combineAdd(items)
		items = CanonAlgebra.combineLikeTerms(items)

		-- sort variables
		table_sort(items, function(a, b)
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		if #items == 0 then return Node.Num("0") end
		if #items == 1 then return items[1] end

		-- rebuild left-associative tree
		local acc = items[1]
		for i = 2, #items do
			acc = Node.Op("+", acc, items[i])
		end
		return acc
	end

	-------------------------------------------------------
	-- MULTIPLICATION
	-------------------------------------------------------
	if op == "*" then
		local items = CanonAlgebra.flatten("*", { left, right })
		for i, n in ipairs(items) do
			items[i] = Canon.canonical(n)
		end

		items = CanonAlgebra.combineMul(items)

		table_sort(items, function(a, b)
			-- numeric first
			if Util.isNum(a) and not Util.isNum(b) then return true end
			if Util.isNum(b) and not Util.isNum(a) then return false end

			-- otherwise fallback to CanonHelpers.canonicalKey
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		if #items == 1 then
			return items[1]
		end

		local acc = items[1]
		for i = 2, #items do
			acc = Node.Op("*", acc, items[i])
		end

		return acc
	end

	-------------------------------------------------------
	-- SUBTRACTION -> normalize to addition
	-------------------------------------------------------
	if op == "-" then
		return Canon.canonical(
			Node.Op("+",
				left,
				Node.Op("*", Node.Num("-1"), right)
			)
		)
	end

	-------------------------------------------------------
	-- EXPONENTIATION
	-------------------------------------------------------
	if op == "^" then
		return Node.Op("^", left, right)
	end

	-------------------------------------------------------
	-- DIVISION + RATIONAL CREATION
	-------------------------------------------------------
	if op == "/" then

		-- x / 1 -> x
		if Util.isOne(right) then
			return left
		end

		-- x/x -> 1 if x ~= 0
		if CanonHelpers.canonicalKey(left) == CanonHelpers.canonicalKey(right) then
			if Util.isVar(left) and Assume.is(left, "nonzero") then
				return Node.Num("1")
			end
		end

		-- both sides are integers -> rational
		if Util.isNum(left) and Util.isNum(right) then
			return Node.Rat(tonumber(left.value), tonumber(right.value))
		end

		-- rational / integer -> rational
		if Util.isRat(left) and Util.isNum(right) then
			return Node.Rat(left.num, left.den * tonumber(right.value))
		end

		-- integer / rational -> rational
		if Util.isNum(left) and Util.isRat(right) then
			return Node.Rat(
				tonumber(left.value) * right.den,
				right.num
			)
		end

		-- rational / rational -> rational
		if Util.isRat(left) and Util.isRat(right) then
			return Node.Rat(
				left.num * right.den,
				left.den * right.num
			)
		end

		-- Otherwise: symbolic division
		return Node.Op("/", left, right)
	end

	-------------------------------------------------------
	-- COMPARISON OPERATORS
	-------------------------------------------------------
	if op == ">" or op == "<" or op == ">=" or op == "<=" or op == "==" or op == "!=" then
		return Node.Op(op, left, right)
	end

	-------------------------------------------------------
	-- LOGICAL OPERATORS
	-------------------------------------------------------
	if op == "and" or op == "or" then
		-- Flatten associative chains
		local items = CanonAlgebra.flatten(op, { left, right })

		-- Canonicalize children
		for i, n in ipairs(items) do
			items[i] = Canon.canonical(n)
		end

		-- Remove duplicates (idempotence)
		local seen = {}
		local unique = {}
		for _, n in ipairs(items) do
			local key = CanonHelpers.canonicalKey(n)
			if not seen[key] then
				seen[key] = true
				table_insert(unique, n)
			end
		end

		-- Sort operands deterministically
		table_sort(unique, function(a, b)
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		-- If only one operand remains, return it
		if #unique == 1 then
			return unique[1]
		end

		-- Rebuild left-associative tree
		local acc = unique[1]
		for i = 2, #unique do
			acc = Node.Op(op, acc, unique[i])
		end

		return acc
	end
end

-- Canonicalizes the complex number.
function Canon._canonicalComplex(node)
	-- Canonicalize children
	local real = Canon.canonical(node.real)
	local imag = Canon.canonical(node.imag)

	-- Case 1: 0 + 0i -> 0
	if Util.isZero(real)
		and Util.isZero(imag) then
		return Node.Num("0")
	end

	-- Case 2: a + 0i -> a
	if Util.isZero(imag) then
		return real
	end

	-- Case 3: 0 + bi -> b*i
	if Util.isZero(real) then
		-- symbolic: b * i
		return Node.Op("*", imag, Node.Const("i"))
	end

	-- Otherwise: keep as complex node
	return Node.Complex(real, imag)
end

-- Canonicalizes the rational
function Canon._canonicalRat(node)
	-- Extract numerator and denominator
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

	-- Reduce by gcd (safety net)
	local g = Util.gcd(math.abs(n), d)
	if g ~= 1 then
		n = n // g
		d = d // g
	end

	-- Collapse integers
	if d == 1 then
		return Node.Num(tostring(n))
	end

	-- Return canonical rational
	return Node.Rat(n, d)
end

-- Canonicalizes the piecewise function.
function Canon._canonicalPiecewise(node)

	-- Flatten nested piecewise: distribute guards
	local function distribute(cond, expr)
		-- If expr is not piecewise, keep as-is
		if not Util.isPiecewise(expr) then
			return { { cond, expr } }
		end

		-- Otherwise: distribute cond over each branch
		local out = {}
		for _, inner in ipairs(expr.branches) do
			local innerCond = inner[1]
			local innerExpr = inner[2]

			-- newCond = cond AND innerCond
			local newCond = Node.Op("and", cond, innerCond)
			newCond = Canon.canonical(newCond)

			table_insert(out, { newCond, innerExpr })
		end
		return out
	end

	local newBranches = {}

	for _, pair in ipairs(node.branches) do
		local cond = Canon.canonical(pair[1])
		local expr = Canon.canonical(pair[2])

		-- Distribute if needed
		local expanded = distribute(cond, expr)

		for _, b in ipairs(expanded) do
			table_insert(newBranches, b)
		end
	end

	return Node.Piecewise(newBranches)
end

-- The Canonical sub-library.
return Canon