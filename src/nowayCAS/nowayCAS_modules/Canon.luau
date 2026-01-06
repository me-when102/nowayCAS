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
-- Steps:
--   1. Flatten associative ops (+, *)
--   2. Sort operands
--   3. Combine numeric constants
--   4. Combine like terms (polynomial-style)
--   5. Normalize subtraction and negation
-------------------------------------------------------

-- deep copy
local function copy(t)
	local n = {}
	for k,v in pairs(t) do n[k] = v end
	return n
end

-- check if node is numeric literal
local function isNum(n)
	return n.kind == "num"
end

-- check if node is variable
local function isVar(n)
	return n.kind == "var"
end

-- check if the node is rational.
local function isRat(n)
	return n.kind == "rat"
end

-- check if node is constant.
local function isConst(n)
	return n.kind == "const"
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
		if n.kind == "num" then
			-- integer literal
			local v = tonumber(n.value)
			sumNum = sumNum + v * sumDen

		elseif n.kind == "rat" then
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
		if n.kind == "num" then
			num = num * tonumber(n.value)

			-- Rational literal
		elseif n.kind == "rat" then
			num = num * n.num
			den = den * n.den

			-- reduce
			local g = Util.gcd(math.abs(num), math.abs(den))
			num = num // g
			den = den // g

			-- Variable
		elseif n.kind == "var" then
			varExp[n.name] = (varExp[n.name] or 0) + 1

			-- Constant
		elseif n.kind == "const" then
			varExp["const:" .. n.name] = (varExp["const:" .. n.name] or 0) + 1

			-- Power: x^n or const^n
		elseif n.kind == "op" and n.op == "^" and isNum(n.right) then
			local exp = tonumber(n.right.value)

			if n.left.kind == "var" then
				varExp[n.left.name] = (varExp[n.left.name] or 0) + exp

			elseif n.left.kind == "const" then
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

	return out
end

-- Returns a canonical monomial descriptor:
-- {
--     coeff = { num = <int>, den = <int> },
--     vars  = { x = 2, y = 1, ["const:pi"] = 1 }
-- }
local function monomialKey(node)
	-- Variable
	if node.kind == "var" then
		return {
			coeff = { num = 1, den = 1 },
			vars  = { [node.name] = 1 }
		}
	end

	-- Integer literal
	if node.kind == "num" then
		return {
			coeff = { num = tonumber(node.value), den = 1 },
			vars  = {}
		}
	end

	-- Rational literal
	if node.kind == "rat" then
		return {
			coeff = { num = node.num, den = node.den },
			vars  = {}
		}
	end

	-- Constant
	if node.kind == "const" then
		return {
			coeff = { num = 1, den = 1 },
			vars  = { ["const:" .. node.name] = 1 }
		}
	end

	-- Power: x^n or const^n
	if node.kind == "op" and node.op == "^" and isNum(node.right) then
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
	if node.kind == "op" and node.op == "*" then
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
	local kind = node.kind

	if kind == "num" or kind == "var" or kind == "const" then
		result = node

	elseif kind == "func" then
		-- Canonicalize each argument
		local newArgs = {}
		for i, a in ipairs(node.args) do
			newArgs[i] = Canon.canonical(a)
		end
		
		-- may be put into a separate function (_canonicalFunc) if another function is added here
		
		-- abs(x) -> x if x > 0
		if node.name == "abs" and #newArgs == 1 then
			local arg = newArgs[1]
			if arg.kind == "var" then
				if Assume.is(arg, "positive") then
					return arg
				elseif Assume.is(arg, "negative") then
					return Node.Op("*", Node.Num("-1"), arg)
				end
			end
		end

		return Node.Func(node.name, newArgs)

	elseif kind == "op" then
		result = Canon._canonicalOp(node)
		
	elseif kind == "rat" then
		result = Canon._canonicalRat(node)
	else
		error("Canonical: unknown node kind '" .. tostring(kind) .. "'")
	end

	CANON_CACHE[node] = result
	return result
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
		
		-- x/x -> 1 if x ~= 0
		if canonicalKey(left) == canonicalKey(right) then
			if left.kind == "var" and Assume.is(left, "nonzero") then
				return Node.Num("1")
			end
		end

		-- both sides are integers -> rational
		if isNum(left) and isNum(right) then
			return Node.Rat(tonumber(left.value), tonumber(right.value))
		end

		-- rational / integer -> rational
		if isRat(left) and isNum(right) then
			return Node.Rat(left.num, left.den * tonumber(right.value))
		end

		-- integer / rational -> rational
		if isNum(left) and isRat(right) then
			return Node.Rat(
				tonumber(left.value) * right.den,
				right.num
			)
		end

		-- rational / rational -> rational
		if isRat(left) and isRat(right) then
			return Node.Rat(
				left.num * right.den,
				left.den * right.num
			)
		end

		-- Otherwise: symbolic division
		return Node.Op("/", left, right)
	end
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

-- The Canonical sub-library
return Canon