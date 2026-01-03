local Canon = {}
local CANON_CACHE = {}

local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)

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

-- check if node is constant
local function isConst(n)
	return n.kind == "const"
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

-- Sort nodes for canonical ordering
-- Variables alphabetically, numbers last
local function sortNodes(nodes)
	table_sort(nodes, function(a, b)
		if isVar(a) and isVar(b) then
			return a.name < b.name
		end
		if isVar(a) and not isVar(b) then return true end
		if not isVar(a) and isVar(b) then return false end

		-- NEW: constants
		if isConst(a) and isConst(b) then
			return a.name < b.name
		end
		if isConst(a) and isNum(b) then return true end
		if isNum(a) and isConst(b) then return false end

		-- fallback: string compare
		return canonicalKey(a.kind) < canonicalKey(b.kind)
	end)
end

-- Combine numeric constants in addition
local function combineAdd(nodes)
	local sum = 0
	local out = {}

	for _, n in ipairs(nodes) do
		if isNum(n) then
			sum = sum + tonumber(n.value)
		else
			table_insert(out, n)
		end
	end

	if sum ~= 0 then
		table_insert(out, Node.Num(tostring(sum)))
	end

	return out
end

-- Combine numeric factors in multiplication
-- Also combine repeated variables into powers: a*a*n*n -> a^2 * n^2
local function combineMul(nodes)
	-- 1. Combine numeric factors
	local prod = 1
	local varExp = {}
	local others = {}

	for _, n in ipairs(nodes) do
		if isNum(n) then
			prod *= tonumber(n.value)

		elseif isVar(n) then
			varExp[n.name] = (varExp[n.name] or 0) + 1

		elseif isConst(n) then
			varExp["const:" .. n.name] = (varExp["const:" .. n.name] or 0) + 1

		elseif n.kind == "op" and n.op == "^" and isNum(n.right) then
			if isVar(n.left) then
				varExp[n.left.name] = (varExp[n.left.name] or 0) + tonumber(n.right.value)
			elseif isConst(n.left) then
				varExp["const:" .. n.left.name] =
					(varExp["const:" .. n.left.name] or 0) + tonumber(n.right.value)
			else
				table_insert(others, n)
			end

		else
			table_insert(others, n)
		end
	end

	local out = {}

	-- 2. Add numeric product if needed
	if prod ~= 1 or (#others == 0 and next(varExp) == nil) then
		table_insert(out, Node.Num(tostring(prod)))
	end

	-- 3. Add variables (with exponents if > 1), sorted by name
	local names = {}
	for name,_ in pairs(varExp) do
		table_insert(names, name)
	end
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
			-- normal variable
			local base = Node.Var(key)

			if exp == 1 then
				table_insert(out, base)
			else
				table_insert(out, Node.Op("^", base, Node.Num(tostring(exp))))
			end
		end
	end

	-- 4. Append all other non‑num, non‑var factors
	for _, n in ipairs(others) do
		table_insert(out, n)
	end

	-- 5. Deterministic order for the whole product
	table_sort(out, function(a, b)
		return canonicalKey(a) < canonicalKey(b)
	end)

	return out
end

-- Returns a canonical string key representing the symbolic part of a product
local function monomialKey(node)
	if node.kind == "var" then
		return { coeff = 1, vars = { [node.name] = 1 } }
	end

	if node.kind == "num" then
		return { coeff = tonumber(node.value), vars = {} }
	end
	
	if node.kind == "const" then
		return { coeff = 1, vars = { ["const:" .. node.name] = 1 } }
	end

	if node.kind == "op" and node.op == "*" then
		local left = monomialKey(node.left)
		local right = monomialKey(node.right)
		if not left or not right then
			return nil
		end

		local coeff = left.coeff * right.coeff
		local vars = {}

		for k,v in pairs(left.vars) do vars[k] = v end
		for k,v in pairs(right.vars) do vars[k] = (vars[k] or 0) + v end

		return { coeff = coeff, vars = vars }
	end

	if node.kind == "op" and node.op == "^" and isNum(node.right) then
		if node.left.kind == "var" then
			return {
				coeff = 1,
				vars = { [node.left.name] = tonumber(node.right.value) }
			}
		elseif node.left.kind == "const" then
			return {
				coeff = 1,
				vars = { ["const:" .. node.left.name] = tonumber(node.right.value) }
			}
		end
	end

	return nil
end

-- Combine like terms: a*x + b*x -> (a+b)*x
local function combineLikeTerms(nodes)
	local buckets = {}
	local others = {}

	-- 1. Bucket only *symbolic* monomials
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

			buckets[key] = buckets[key] or { coeff = 0, vars = m.vars }
			buckets[key].coeff += m.coeff
		end
	end

	-- 2. Rebuild each combined symbolic monomial
	for _, b in pairs(buckets) do
		if b.coeff ~= 0 then
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
			if b.coeff ~= 1 then
				table_insert(factors, 1, Node.Num(tostring(b.coeff)))
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

		result = Node.Func(node.name, newArgs)

	elseif kind == "op" then
		result = Canon._canonicalOp(node)

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
		sortNodes(items)
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
		sortNodes(items)
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
	-- DIVISION (no special canonicalization yet)
	-------------------------------------------------------
	if op == "/" then
		return Node.Op("/", left, right)
	end
end
-- The Canonical sub-library
return Canon