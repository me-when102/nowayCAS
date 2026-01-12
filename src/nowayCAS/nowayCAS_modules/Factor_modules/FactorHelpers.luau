local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)
local Util = require(script.Parent.Parent.Util)

local FactorHelpers = {}

local table_insert = table.insert

local ipairs = ipairs
local pairs = pairs
local type = type

-------------------------------------------------------
-- Factorization Helpers
-- Common helpers for the factorization subsystem.
-- TODO: FactorHelpers is in pain, perhaps if Factor gets fixed try increasing maintainability index if possible.
-------------------------------------------------------

function FactorHelpers.minExponentAcross(terms, name)
	local minExp = terms[1].varExp[name] or 0
	for i = 2, #terms do
		minExp = math.min(minExp, terms[i].varExp[name] or 0)
	end
	return minExp
end

function FactorHelpers.intersectOthers(terms)
	local others = {}
	for _, n in ipairs(terms[1].others or {}) do
		local ok = true
		for i = 2, #terms do
			local found = false
			for _, m in ipairs(terms[i].others or {}) do
				if Util.nodeEquals(n, m) then found = true; break end
			end
			if not found then ok = false; break end
		end
		if ok then table.insert(others, n) end
	end
	return others
end

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
		local minExp = FactorHelpers.minExponentAcross(terms, name)
		if minExp > 0 then varExp[name] = minExp end
	end

	-- intersection of "others" using structural equality
	local others =  FactorHelpers.intersectOthers(terms)

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
	if Util.isOp(node) and node.op == op then
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
		if Util.isNum(n) then
			num = num * tonumber(n.value)

		elseif Util.isVar(n) then
			varExp[n.name] = (varExp[n.name] or 0) + 1

		elseif Util.isOp(n) and n.op == "^"
			and Util.isVar(n.left)
			and Util.isNum(n.right) then

			varExp[n.left.name] =
				(varExp[n.left.name] or 0) + tonumber(n.right.value)

		elseif Util.isOp(n) and n.op == "*" then
			local parts = {}
			FactorHelpers.factor_flatten(n, "*", parts)
			for _, p in ipairs(parts) do
				if Util.isNum(p) then
					num = num * tonumber(p.value)
				elseif Util.isVar(p) then
					varExp[p.name] = (varExp[p.name] or 0) + 1
				elseif Util.isOp(p) and p.op == "^"
					and Util.isVar(p.left)
					and Util.isNum(p.right) then
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

-- Builds a sequence of multiplication nodes.
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

-- Build an addition sum node sequence with a table of nodes.
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

-- Normalizes the node remainder.
function FactorHelpers.normalizeRemainder(node)
	local n = Canon.canonical(node)
	if not (Util.isOp(n) and n.op == "+") then
		n = Canon.canonical(Node.Op("+", n, Node.Num("0")))
	end
	return n
end

-- Gets the coefficient of the node, regardless if it is a number or a rational.
function FactorHelpers.getCoeff(node)
	if Util.isNum(node) then
		return node.value, 1
	elseif Util.isRat(node) then
		return node.num, node.den
	else
		return nil
	end
end

-- Remove v^k from a term T, returning T / v^k
function FactorHelpers.removeVarPower(node, var, k)
	-- Extract the term structure
	local ex = FactorHelpers.extractTerm(node)

	-- Adjust exponent
	local newExp = (ex.varExp[var] or 0) - k
	if newExp < 0 then
		-- Should never happen if caller is correct
		return node
	end

	-- Rebuild factors
	local factors = {}

	-- numeric coefficient
	if ex.num ~= 1 or (next(ex.varExp) == nil and #ex.others == 0) then
		table_insert(factors, Node.Num(tostring(ex.num)))
	end

	-- symbolic factors
	for name, exp in pairs(ex.varExp) do
		if name ~= var then
			-- untouched variable
			if exp == 1 then
				table_insert(factors, Node.Var(name))
			else
				table_insert(factors, Node.Op("^", Node.Var(name), Node.Num(tostring(exp))))
			end
		else
			-- reduced exponent
			if newExp > 0 then
				if newExp == 1 then
					table_insert(factors, Node.Var(var))
				else
					table_insert(factors, Node.Op("^", Node.Var(var), Node.Num(tostring(newExp))))
				end
			end
		end
	end

	-- other symbolic factors (non‑var/const)
	for _, o in ipairs(ex.others) do
		table_insert(factors, o)
	end

	-- If no factors left, return 1
	if #factors == 0 then
		return Node.Num("1")
	end

	-- Fold into product
	local out = factors[1]
	for i = 2, #factors do
		out = Node.Op("*", out, factors[i])
	end

	return out
end

-- Return symbolic factor pairs {p, q} such that p*q = expr.
-- Shallow, non-recursive, but handles numeric coefficients and variable powers.
function FactorHelpers.factorPairs(expr)
	local factor_pairs = {}

	-- Extract monomial structure
	local ex = FactorHelpers.extractTerm(expr)

	-- If expr has "others" (non-monomial factors), fall back to trivial pairs
	if #ex.others > 0 then
		return {
			{ Node.Num("1"), expr },
			{ expr, Node.Num("1") }
		}
	end

	-- Numeric factor pairs
	local num = ex.num
	local absn = math.abs(num)

	local numericPairs = {}

	if absn == 0 then
		-- 0 only has trivial pairs
		numericPairs = {
			{ Node.Num("0"), Node.Num("1") },
			{ Node.Num("1"), Node.Num("0") }
		}
	else
		for i = 1, absn do
			if absn % i == 0 then
				local a = i
				local b = absn // i

				if num < 0 then
					table_insert(numericPairs, { Node.Num(tostring(-a)), Node.Num(tostring(b)) })
					table_insert(numericPairs, { Node.Num(tostring(a)), Node.Num(tostring(-b)) })
				else
					table_insert(numericPairs, { Node.Num(tostring(a)), Node.Num(tostring(b)) })
					table_insert(numericPairs, { Node.Num(tostring(-a)), Node.Num(tostring(-b)) })
				end
			end
		end
	end

	-- Variable exponent splits
	-- For each variable x^k, split exponent into i + (k-i)
	local varSplits = {}

	local function buildVarFactor(name, exp)
		if exp == 0 then
			return Node.Num("1")
		elseif exp == 1 then
			return Node.Var(name)
		else
			return Node.Op("^", Node.Var(name), Node.Num(tostring(exp)))
		end
	end

	-- Build all exponent splits for each variable
	local varNames = {}
	for name,_ in pairs(ex.varExp) do table_insert(varNames, name) end

	-- Start with identity pair
	varSplits[1] = { Node.Num("1"), Node.Num("1") }

	for _, name in ipairs(varNames) do
		local k = ex.varExp[name]
		local newSplits = {}

		for _, pair in ipairs(varSplits) do
			for i = 0, k do
				local leftExp  = i
				local rightExp = k - i

				local leftFactor  = buildVarFactor(name, leftExp)
				local rightFactor = buildVarFactor(name, rightExp)

				-- multiply into existing pair
				local L = Node.Op("*", pair[1], leftFactor)
				local R = Node.Op("*", pair[2], rightFactor)

				table_insert(newSplits, { L, R })
			end
		end

		varSplits = newSplits
	end

	-- Combine numeric pairs with variable exponent pairs
	for _, np in ipairs(numericPairs) do
		for _, vp in ipairs(varSplits) do
			local p = Node.Op("*", np[1], vp[1])
			local q = Node.Op("*", np[2], vp[2])

			table_insert(factor_pairs, { p, q })
		end
	end

	-- Always include trivial pairs
	table_insert(factor_pairs, { Node.Num("1"), expr })
	table_insert(factor_pairs, { expr, Node.Num("1") })

	return factor_pairs
end

-- Checks if the node is a simple monomial
function FactorHelpers.isSimpleMonomial(node)
	-- Extract monomial structure
	local ex = FactorHelpers.extractTerm(node)

	-- Must have no "others" (no non-monomial factors)
	if #ex.others > 0 then
		return false
	end

	-- Numeric coefficient must be a perfect square (up to sign)
	local coeff = ex.num
	local absCoeff = math.abs(coeff)
	local r = math.sqrt(absCoeff)

	-- reject if not a perfect square
	if r ~= math.floor(r) then
		return false
	end

	-- All variable exponents are fine (extractTerm guarantees integers)

	-- No multiple distinct variables allowed (u or v must be single-variable monomials)
	local countVars = 0
	for _ in pairs(ex.varExp) do
		countVars = countVars + 1
		if countVars > 1 then
			return false
		end
	end

	return true
end

-- Detect n = +-(K * U^2) where K is a perfect square (possibly 1),
-- returning (true, base, sign), where base is K^(1/2) * U and sign is +-1.
function FactorHelpers.getSquareBaseSigned(n)
	-- pure symbolic square: u^2
	if Util.isOp(n) and n.op == "^" then
		if Util.isNum(n.right) and tonumber(n.right.value) == 2 then
			return true, n.left, 1
		end
	end

	-- pure numeric square: +-k
	if Util.isNum(n) then
		local v = tonumber(n.value)
		if v then
			local r = math.sqrt(math.abs(v))
			if r == math.floor(r) then
				local base = Node.Num(tostring(r))
				local sign = (v >= 0) and 1 or -1
				return true, base, sign
			end
		end
	end

	-- general monomial with coefficient and powers, e.g. 9x^2, -25y^2, 49a^2
	-- Use FactorHelpers.extractTerm to pull out numeric coefficient and symbolic factors.
	local ex = FactorHelpers.extractTerm(n)

	-- We only handle pure monomials: no "others"
	if #ex.others > 0 then
		return false, nil, nil
	end

	-- All exponents must be even to be a square
	for _, exp in pairs(ex.varExp) do
		if exp % 2 ~= 0 then
			return false, nil, nil
		end
	end

	-- Coefficient must be a perfect square up to sign
	local coeff = ex.num
	if coeff == 0 then
		-- 0 is a square: 0^2
		return true, Node.Num("0"), 1
	end

	local sign = (coeff >= 0) and 1 or -1
	local absCoeff = math.abs(coeff)
	local r = math.sqrt(absCoeff)
	if r ~= math.floor(r) then
		return false, nil, nil
	end

	-- Build base = r * Π var^(exp/2)
	local factors = {}

	-- numeric part
	if r ~= 1 then
		table_insert(factors, Node.Num(tostring(r)))
	end

	-- symbolic part: each var^(exp/2)
	for name, exp in pairs(ex.varExp) do
		local half = exp // 2
		local base
		if name:sub(1,6) == "const:" then
			base = Node.Const(name:sub(7))
		else
			base = Node.Var(name)
		end

		if half == 1 then
			table_insert(factors, base)
		else
			table_insert(factors, Node.Op("^", base, Node.Num(tostring(half))))
		end
	end

	-- If no symbolic factors and r == 1, it's just 1
	if #factors == 0 then
		table_insert(factors, Node.Num("1"))
	end

	-- Fold factors into a product or single node
	local baseNode = factors[1]
	for i = 2, #factors do
		baseNode = Node.Op("*", baseNode, factors[i])
	end

	return true, baseNode, sign
end

return FactorHelpers