local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)
local Util = require(script.Parent.Parent.Util)

local FactorHelpers = {}

local table_insert = table.insert

local ipairs = ipairs
local type = type

-------------------------------------------------------
-- Factorization Helpers
-------------------------------------------------------

-- Compute the common factor descriptor for a list of term descriptors.
-- Input: terms = { { num, varExp, others }, ... }
-- Output: { num, varExp, others }
function FactorHelpers.commonFactor(terms)
	assert(type(terms) == "table" and #terms >= 1, "commonFactor expects non-empty terms list")

	-- numeric gcd
	local g = math.abs(terms[1].num or 1)
	for i = 2, #terms do
		g = Util.gcd(g, math.abs(terms[i].num or 1))
	end

	-- variable min exponents
	local varExp = {}
	for name, exp in pairs(terms[1].varExp or {}) do
		local minExp = exp
		for i = 2, #terms do
			minExp = math.min(minExp, terms[i].varExp[name] or 0)
		end
		if minExp > 0 then varExp[name] = minExp end
	end

	-- intersection of "others" using structural equality
	local others = {}
	for _, n in ipairs(terms[1].others or {}) do
		local ok = true
		for i = 2, #terms do
			local found = false
			for _, m in ipairs(terms[i].others or {}) do
				if Util.nodeEquals(n, m) then
					found = true
					break
				end
			end
			if not found then
				ok = false
				break
			end
		end
		if ok then table_insert(others, n) end
	end

	return { num = g, varExp = varExp, others = others }
end

-- Test whether a factor descriptor divides a term descriptor.
-- Returns true if factor.num divides term.num, factor.varExp <= term.varExp, and every factor.other appears in term.others.
function FactorHelpers.factorDividesTerm(factor, term)
	if not factor or not term then return false end

	-- numeric part: factor.num must divide term.num (handle zero safely)
	if factor.num ~= 0 and (term.num % factor.num) ~= 0 then
		return false
	end

	-- variable exponents: term must have at least as much of each var
	for name, exp in pairs(factor.varExp or {}) do
		if (term.varExp[name] or 0) < exp then
			return false
		end
	end

	-- "others": every factor.others node must appear in term.others
	for _, fnode in ipairs(factor.others or {}) do
		local found = false
		for _, tnode in ipairs(term.others or {}) do
			if Util.nodeEquals(tnode, fnode) then
				found = true
				break
			end
		end
		if not found then return false end
	end

	return true
end

-- Divide a term descriptor by a factor descriptor, returning the remainder descriptor.
-- Assumes factorDividesTerm(factor, term) is true. Removes zero exponents.
function FactorHelpers.divideTerm(term, factor)
	local num = (term.num or 1) / (factor.num or 1)

	local varExp = {}
	for name, exp in pairs(term.varExp or {}) do
		local newExp = exp - (factor.varExp[name] or 0)
		if newExp ~= 0 then varExp[name] = newExp end
	end

	local others = {}
	for _, n in ipairs(term.others or {}) do
		local remove = false
		for _, m in ipairs(factor.others or {}) do
			if Util.nodeEquals(n, m) then
				remove = true
				break
			end
		end
		if not remove then table_insert(others, n) end
	end

	return { num = num, varExp = varExp, others = others }
end

function FactorHelpers.factor_flatten(node, op, out)
	if node.kind == "op" and node.op == op then
		FactorHelpers.factor_flatten(node.left, op, out)
		FactorHelpers.factor_flatten(node.right, op, out)
	else
		table_insert(out, node)
	end
end

function FactorHelpers.extractTerm(node)
	local factors = {}
	FactorHelpers.factor_flatten(node, "*", factors)

	local num = 1
	local varExp = {}
	local others = {}

	for _, n in ipairs(factors) do
		if n.kind == "num" then
			num = num * tonumber(n.value)

		elseif n.kind == "var" then
			varExp[n.name] = (varExp[n.name] or 0) + 1

		elseif n.kind == "op" and n.op == "^"
			and n.left and n.left.kind == "var"
			and n.right and n.right.kind == "num" then

			varExp[n.left.name] =
				(varExp[n.left.name] or 0) + tonumber(n.right.value)

		elseif n.kind == "op" and n.op == "*" then
			local parts = {}
			FactorHelpers.factor_flatten(n, "*", parts)
			for _, p in ipairs(parts) do
				if p.kind == "num" then
					num = num * tonumber(p.value)
				elseif p.kind == "var" then
					varExp[p.name] = (varExp[p.name] or 0) + 1
				elseif p.kind == "op" and p.op == "^"
					and p.left and p.left.kind == "var"
					and p.right and p.right.kind == "num" then
					varExp[p.left.name] = (varExp[p.left.name] or 0) + tonumber(p.right.value)
				else
					table_insert(others, p)
				end
			end

		else
			table_insert(others, n)
		end
	end

	return {
		num = num,
		varExp = varExp,
		others = others,
	}
end

function FactorHelpers.buildMul(f)
	local parts = {}

	if f.num ~= 1 then
		table_insert(parts, Node.Num(tostring(f.num)))
	end

	local varNames = {}
	for name, exp in pairs(f.varExp) do
		if exp and exp > 0 then
			table_insert(varNames, name)
		end
	end
	table.sort(varNames)

	for _, name in ipairs(varNames) do
		local exp = f.varExp[name]
		if exp == 1 then
			table_insert(parts, Node.Var(name))
		else
			table_insert(parts, Node.Op("^", Node.Var(name), Node.Num(tostring(exp))))
		end
	end

	for _, n in ipairs(f.others) do
		table_insert(parts, n)
	end

	if #parts == 0 then return Node.Num("1") end

	local result = parts[1]
	for i = 2, #parts do
		result = Node.Op("*", result, parts[i])
	end

	return result
end

-- these things to document (help)

function FactorHelpers.buildAdd(nodes)
	if #nodes == 0 then
		return Node.Num("0")
	end

	local acc = nodes[1]
	for i = 2, #nodes do
		acc = Node.Op("+", acc, nodes[i])
	end
	return acc
end

function FactorHelpers.normalizeRemainder(node)
	local n = Canon.canonical(node)
	if not (n.kind == "op" and n.op == "+") then
		n = Canon.canonical(Node.Op("+", n, Node.Num("0")))
	end
	return n
end

-- RATIONAL
function FactorHelpers.getCoeff(node)
	if node.kind == "num" then
		return node.value, 1
	elseif node.kind == "rat" then
		return node.num, node.den
	else
		return nil
	end
end

return FactorHelpers