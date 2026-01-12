local Canon = {}
local CANON_CACHE = {}

local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)
local Assume = require(script.Parent.Assume)

local table_insert = table.insert
local table_sort = table.sort

local ipairs = ipairs

-------------------------------------------------------
-- Canonicalizer
-- Produces a unique, normalized AST form.
-------------------------------------------------------

-- deep copy
local function copy(t)
	local n = {}
	for k,v in pairs(t) do n[k] = v end
	return n
end

-- Rational Addition.
local function ratAdd(a, b)
	-- a = {num, den}, b = {num, den}
	local num = a.num * b.den + b.num * a.den
	local den = a.den * b.den
	local g = Util.gcd(math.abs(num), math.abs(den))
	return { num = num // g, den = den // g }
end

-- Check if the rational is zero.
local function ratIsZero(r)
	return r.num == 0
end

-- Check if the rational is one.
local function ratIsOne(r)
	return r.num == r.den
end

-- Flatten associative operators
local function flatten(op, items)
	local out = {}

	local function add(n)
		if n.kind == "op" and n.op == op then
			add(n.left)
			add(n.right)
		else
			table_insert(out, n)
		end
	end

	for _, n in ipairs(items) do add(n) end
	return out
end

-- Get canonical key for deterministic stuff.
local function canonicalKey(node)
	if node.kind == "num" then
		return "num:" .. node.value
	elseif node.kind == "var" then
		return "var:" .. node.name
	elseif node.kind == "const" then
		return "const:" .. node.name
	elseif node.kind == "complex" then
		return "complex(" .. canonicalKey(node.real) .. "," .. canonicalKey(node.imag) .. ")"
	elseif node.kind == "func" then
		local parts = { "func:", node.name, "(" }
		for i, arg in ipairs(node.args) do
			if i > 1 then table_insert(parts, ",") end
			table_insert(parts, canonicalKey(arg))
		end
		table_insert(parts, ")")
		return table.concat(parts)
	elseif node.kind == "op" then
		return "op:" .. node.op .. "("
			.. canonicalKey(node.left) .. ","
			.. canonicalKey(node.right) .. ")"
	else
		return node.kind or "?"
	end
end

-- Combine numeric constants in addition
local function combineAdd(nodes)
	-- running rational sum: sum = sumNum / sumDen
	local sumNum = 0
	local sumDen = 1

	local out = {}

	for _, n in ipairs(nodes) do
		if Util.isNum(n) then
			-- integer literal
			local v = tonumber(n.value)
			sumNum = sumNum + v * sumDen

		elseif Util.isRat(n) then
			-- rational literal
			local n2 = n.num
			local d2 = n.den

			-- sum = sum + n2/d2
			sumNum = sumNum * d2 + n2 * sumDen
			sumDen = sumDen * d2

			-- reduce
			local g = Util.gcd(math.abs(sumNum), math.abs(sumDen))
			sumNum = sumNum // g
			sumDen = sumDen // g

		else
			-- symbolic term, keep it
			table_insert(out, n)
		end
	end

	-- emit numeric result if nonzero
	if sumNum ~= 0 then
		if sumDen == 1 then
			table_insert(out, Node.Num(tostring(sumNum)))
		else
			table_insert(out, Node.Rat(sumNum, sumDen))
		end
	end

	return out
end

-- Combine numeric factors in multiplication
-- Also combine repeated variables into powers: a*a*n*n -> a^2 * n^2
local function combineMul(nodes)
	-- Rational accumulator for coefficient
	local num = 1
	local den = 1

	local varExp = {}
	local others = {}

	for _, n in ipairs(nodes) do

		-- Integer literal
		if Util.isNum(n) then
			num = num * tonumber(n.value)

			-- Rational literal
		elseif Util.isRat(n) then
			num = num * n.num
			den = den * n.den

			-- reduce
			local g = Util.gcd(math.abs(num), math.abs(den))
			num = num // g
			den = den // g

			-- Variable
		elseif Util.isVar(n) then
			varExp[n.name] = (varExp[n.name] or 0) + 1

			-- Constant
		elseif Util.isConst(n) then
			varExp["const:" .. n.name] = (varExp["const:" .. n.name] or 0) + 1

			-- Power: x^n or const^n
		elseif Util.isOp(n) and n.op == "^" and Util.isNum(n.right) then
			local exp = tonumber(n.right.value)

			if Util.isVar(n.left) then
				varExp[n.left.name] = (varExp[n.left.name] or 0) + exp

			elseif Util.isConst(n.left) then
				local key = "const:" .. n.left.name
				varExp[key] = (varExp[key] or 0) + exp

			else
				table_insert(others, n)
			end

			-- Everything else
		else
			table_insert(others, n)
		end
	end

	-- Build output list
	local out = {}

	-- Emit numeric/rational coefficient
	if num ~= 1 or den ~= 1 or (#others == 0 and next(varExp) == nil) then
		if den == 1 then
			table_insert(out, Node.Num(tostring(num)))
		else
			table_insert(out, Node.Rat(num, den))
		end
	end

	-- If the numeric coefficient is zero, the whole product is zero.
	if num == 0 then
		return { Node.Num("0") }
	end

	-- Emit variables/constants with exponents
	local names = {}
	for name,_ in pairs(varExp) do table_insert(names, name) end
	table_sort(names)

	for _, key in ipairs(names) do
		local exp = varExp[key]

		if key:sub(1,6) == "const:" then
			local cname = key:sub(7)
			local base = Node.Const(cname)

			if exp == 1 then
				table_insert(out, base)
			else
				table_insert(out, Node.Op("^", base, Node.Num(tostring(exp))))
			end

		else
			local base = Node.Var(key)

			if exp == 1 then
				table_insert(out, base)
			else
				table_insert(out, Node.Op("^", base, Node.Num(tostring(exp))))
			end
		end
	end

	-- Emit other factors
	for _, n in ipairs(others) do
		table_insert(out, n)
	end

	-- Deterministic ordering
	table_sort(out, function(a, b)
		return canonicalKey(a) < canonicalKey(b)
	end)

	-- Collapse repeated non-variable factors: (f)(f) -> f^2
	do
		local buckets = {}
		local reps = {}

		-- Count occurrences of each factor by canonical key
		for _, n in ipairs(out) do
			local key = canonicalKey(n)
			buckets[key] = (buckets[key] or 0) + 1
			reps[key] = reps[key] or n
		end

		-- Rebuild with exponent nodes for repeated factors
		local collapsed = {}
		for key, count in pairs(buckets) do
			local base = reps[key]
			if count == 1 then
				table_insert(collapsed, base)
			else
				table_insert(collapsed, Node.Op("^", base, Node.Num(tostring(count))))
			end
		end

		out = collapsed
	end

	return out
end

-- Returns a canonical monomial descriptor:
-- {
--     coeff = { num = <int>, den = <int> },
--     vars  = { x = 2, y = 1, ["const:pi"] = 1 }
-- }
local function monomialKey(node)
	-- Variable
	if Util.isVar(node) then
		return {
			coeff = { num = 1, den = 1 },
			vars  = { [node.name] = 1 }
		}
	end

	-- Integer literal
	if Util.isNum(node) then
		return {
			coeff = { num = tonumber(node.value), den = 1 },
			vars  = {}
		}
	end

	-- Rational literal
	if Util.isRat(node) then
		return {
			coeff = { num = node.num, den = node.den },
			vars  = {}
		}
	end

	-- Constant
	if Util.isConst(node) then
		return {
			coeff = { num = 1, den = 1 },
			vars  = { ["const:" .. node.name] = 1 }
		}
	end

	-- Power: x^n or const^n
	if Util.isOp(node) and node.op == "^" and Util.isNum(node.right) then
		local exp = tonumber(node.right.value)

		if node.left.kind == "var" then
			return {
				coeff = { num = 1, den = 1 },
				vars  = { [node.left.name] = exp }
			}
		elseif node.left.kind == "const" then
			return {
				coeff = { num = 1, den = 1 },
				vars  = { ["const:" .. node.left.name] = exp }
			}
		end
	end

	-- Multiplication: combine recursively
	if Util.isOp(node) and node.op == "*" then
		local left  = monomialKey(node.left)
		local right = monomialKey(node.right)

		-- If either side is non‑monomial, bail out
		if not left or not right then
			return nil
		end

		-- Combine coefficients: (a/b) * (c/d) = (ac)/(bd)
		local num = left.coeff.num * right.coeff.num
		local den = left.coeff.den * right.coeff.den
		local g   = Util.gcd(math.abs(num), math.abs(den))
		num = num // g
		den = den // g

		-- Combine variable exponents
		local vars = {}
		for k,v in pairs(left.vars)  do vars[k] = v end
		for k,v in pairs(right.vars) do vars[k] = (vars[k] or 0) + v end

		return {
			coeff = { num = num, den = den },
			vars  = vars
		}
	end

	-- Not a monomial
	return nil
end

-- Combine like terms: a*x + b*x -> (a+b)*x
local function combineLikeTerms(nodes)
	local buckets = {}
	local others = {}

	-- Bucket only symbolic monomials
	for _, n in ipairs(nodes) do
		local m = monomialKey(n)

		-- Skip pure numeric constants — let combineAdd handle them
		if not m or (next(m.vars) == nil) then
			table_insert(others, n)
		else
			-- Build key from variable/exponent signature
			local names = {}
			for k,_ in pairs(m.vars) do table_insert(names, k) end
			table_sort(names)

			local key = ""
			for _, name in ipairs(names) do
				key ..= name .. "^" .. m.vars[name] .. ";"
			end

			if not buckets[key] then
				buckets[key] = {
					coeff = { num = m.coeff.num, den = m.coeff.den },
					vars = table.clone(m.vars)
				}
			else
				buckets[key].coeff = ratAdd(buckets[key].coeff, m.coeff)
			end
		end
	end

	-- Rebuild each combined symbolic monomial
	for _, b in pairs(buckets) do
		if not ratIsZero(b.coeff) then
			local factors = {}

			-- Add symbolic factors
			local names = {}
			for name,_ in pairs(b.vars) do table_insert(names, name) end
			table_sort(names)

			for _, name in ipairs(names) do
				local exp = b.vars[name]
				local base = Util.buildSymbol(name)

				if exp == 1 then
					table_insert(factors, base)
				else
					table_insert(factors, Node.Op("^", base, Node.Num(tostring(exp))))
				end
			end

			-- Add numeric coefficient
			local c = b.coeff
			if not ratIsOne(c) then
				if c.den == 1 then
					table_insert(factors, 1, Node.Num(tostring(c.num)))
				else
					table_insert(factors, 1, Node.Rat(c.num, c.den))
				end
			end

			-- Sort factors canonically
			table_sort(factors, function(a, b)
				return canonicalKey(a) < canonicalKey(b)
			end)

			-- Fold into left-associative product
			local term = factors[1]
			for i = 2, #factors do
				term = Node.Op("*", term, factors[i])
			end

			table_insert(others, term)
		end
	end

	return others
end

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
		local items = flatten("+", { left, right })
		for i,n in ipairs(items) do items[i] = Canon.canonical(n) end

		items = combineAdd(items)
		items = combineLikeTerms(items)

		-- sort variables
		table_sort(items, function(a, b)
			return canonicalKey(a) < canonicalKey(b)
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
		local items = flatten("*", { left, right })
		for i, n in ipairs(items) do
			items[i] = Canon.canonical(n)
		end

		items = combineMul(items)

		table_sort(items, function(a, b)
			-- numeric first
			if Util.isNum(a) and not Util.isNum(b) then return true end
			if Util.isNum(b) and not Util.isNum(a) then return false end

			-- otherwise fallback to canonicalKey
			return canonicalKey(a) < canonicalKey(b)
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
		if canonicalKey(left) == canonicalKey(right) then
			if left.kind == "var" and Assume.is(left, "nonzero") then
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
		local items = flatten(op, { left, right })

		-- Canonicalize children
		for i, n in ipairs(items) do
			items[i] = Canon.canonical(n)
		end

		-- Remove duplicates (idempotence)
		local seen = {}
		local unique = {}
		for _, n in ipairs(items) do
			local key = canonicalKey(n)
			if not seen[key] then
				seen[key] = true
				table_insert(unique, n)
			end
		end

		-- Sort operands deterministically
		table_sort(unique, function(a, b)
			return canonicalKey(a) < canonicalKey(b)
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