local Canon = {}
local CANON_CACHE = {}

local Node = require(script.Parent.Node)

local table_insert = table.insert

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

-- Utility: deep copy
local function copy(t)
	local n = {}
	for k,v in pairs(t) do n[k] = v end
	return n
end

-- Utility: check if node is numeric literal
local function isNum(n)
	return n.kind == "num"
end

-- Utility: check if node is variable
local function isVar(n)
	return n.kind == "var"
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

-- Sort nodes for canonical ordering
-- Variables alphabetically, numbers last
local function sortNodes(nodes)
	table.sort(nodes, function(a, b)
		if isVar(a) and isVar(b) then
			return a.name < b.name
		end
		if isVar(a) and isNum(b) then return true end
		if isNum(a) and isVar(b) then return false end
		if isNum(a) and isNum(b) then
			return tonumber(a.value) < tonumber(b.value)
		end
		-- fallback: string compare
		return tostring(a.kind) < tostring(b.kind)
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
		elseif n.kind == "op" and n.op == "^"
			and isVar(n.left) and isNum(n.right) then
			varExp[n.left.name] = (varExp[n.left.name] or 0) + tonumber(n.right.value)
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
	table.sort(names)

	for _, name in ipairs(names) do
		local exp = varExp[name]
		if exp == 1 then
			table_insert(out, Node.Var(name))
		else
			table_insert(out,
				Node.Op("^",
					Node.Var(name),
					Node.Num(tostring(exp))
				)
			)
		end
	end

	-- 4. Append all other non‑num, non‑var factors
	for _, n in ipairs(others) do
		table_insert(out, n)
	end

	-- 5. Deterministic order for the whole product
	table.sort(out, function(a, b)
		return tostring(a) < tostring(b)
	end)

	return out
end

-- get monomial key if possible
local function monomialKey(node)
	if node.kind == "var" then
		return { coeff = 1, vars = { [node.name] = 1 } }
	end

	if node.kind == "num" then
		return { coeff = tonumber(node.value), vars = {} }
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

	if node.kind == "op" and node.op == "^" and node.left.kind == "var" and isNum(node.right) then
		return {
			coeff = 1,
			vars = { [node.left.name] = tonumber(node.right.value) }
		}
	end

	return nil
end

-- Combine like terms: a*x + b*x -> (a+b)*x
local function combineLikeTerms(nodes)
	local buckets = {}
	local others = {}

	for _, n in ipairs(nodes) do
		local m = monomialKey(n)
		if not m then
			table_insert(others, n)
		else
			-- build a canonical key string
			local names = {}
			for k,_ in pairs(m.vars) do table_insert(names, k) end
			table.sort(names)

			local key = ""
			for _, name in ipairs(names) do
				key ..= name .. "^" .. m.vars[name] .. ";"
			end

			buckets[key] = buckets[key] or { coeff = 0, vars = m.vars }
			buckets[key].coeff += m.coeff
		end
	end

	-- rebuild combined monomials
	for _, b in pairs(buckets) do
		if b.coeff ~= 0 then
			local term

			local names = {}
			for name,_ in pairs(b.vars) do
				table_insert(names, name)
			end
			table.sort(names)

			for _, name in ipairs(names) do
				local exp = b.vars[name]
				local v = Node.Var(name)
				local factor = (exp == 1)
					and v
					or Node.Op("^", v, Node.Num(tostring(exp)))

				if not term then
					term = factor
				else
					term = Node.Op("*", term, factor)
				end
			end

			if not term then
				term = Node.Num(tostring(b.coeff))
			elseif b.coeff == 1 then
				-- leave as is
			elseif b.coeff == -1 then
				term = Node.Op("*", Node.Num("-1"), term)
			else
				term = Node.Op("*", Node.Num(tostring(b.coeff)), term)
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

	if kind == "num" or kind == "var" then
		result = node

	elseif kind == "func" then
		result = Node.Func(node.name, Canon.canonical(node.arg))

	elseif kind == "op" then
		result = Canon._canonicalOp(node)

	else
		error("Canonical: unknown node kind '" .. tostring(kind) .. "'")
	end

	CANON_CACHE[node] = result
	return result
end

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