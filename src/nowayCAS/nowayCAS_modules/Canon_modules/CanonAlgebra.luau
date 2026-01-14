local CanonAlgebra = {}
local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)
local CanonNumeric = require(script.Parent.CanonNumeric)
local CanonHelpers = require(script.Parent.CanonHelpers)

local table_insert = table.insert
local table_sort = table.sort

-- Flatten associative operators
function CanonAlgebra.flatten(op, items)
	local out = {}

	local function add(n)
		if Util.isOp(n) and n.op == op then
			add(n.left)
			add(n.right)
		else
			table_insert(out, n)
		end
	end

	for _, n in ipairs(items) do add(n) end
	return out
end

-- Accumulate symbolic exponents (vars, consts, x^n) or classify as other.
function CanonAlgebra.mulAccSymbol(accExp, n, others)
	if Util.isVar(n) then
		accExp[n.name] = (accExp[n.name] or 0) + 1
		return
	end

	if Util.isConst(n) then
		local key = "const:" .. n.name
		accExp[key] = (accExp[key] or 0) + 1
		return
	end

	if Util.isOp(n) and n.op == "^" and Util.isNum(n.right) then
		local exp = tonumber(n.right.value)

		if Util.isVar(n.left) then
			accExp[n.left.name] = (accExp[n.left.name] or 0) + exp
			return
		end

		if Util.isConst(n.left) then
			local key = "const:" .. n.left.name
			accExp[key] = (accExp[key] or 0) + exp
			return
		end
	end

	table_insert(others, n)
end

-- Emit numeric coefficient into out; return true if product collapses to zero.
function CanonAlgebra.mulEmitCoefficient(acc, out, hasOtherFactors)
	if acc.num ~= 1 or acc.den ~= 1 or not hasOtherFactors then
		if acc.den == 1 then
			table_insert(out, Node.Num(tostring(acc.num)))
		else
			table_insert(out, Node.Rat(acc.num, acc.den))
		end
	end

	if acc.num == 0 then
		return true -- product collapses to zero
	end

	return false
end

-- Emit symbolic factors (vars, consts, powers) in canonical order.
function CanonAlgebra.mulEmitSymbolic(accExp, out)
	local names = {}
	for name,_ in pairs(accExp) do table_insert(names, name) end
	table_sort(names)

	for _, key in ipairs(names) do
		local exp = accExp[key]

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
end

-- Collapse repeated non-variable factors into exponent form.
function CanonAlgebra.mulCollapseRepeats(out)
	local buckets = {}
	local reps = {}

	for _, n in ipairs(out) do
		local key = CanonHelpers.canonicalKey(n)
		buckets[key] = (buckets[key] or 0) + 1
		reps[key] = reps[key] or n
	end

	local collapsed = {}
	for key, count in pairs(buckets) do
		local base = reps[key]
		if count == 1 then
			table_insert(collapsed, base)
		else
			table_insert(collapsed, Node.Op("^", base, Node.Num(tostring(count))))
		end
	end

	return collapsed
end

-- Combine numeric constants in addition.
function CanonAlgebra.combineAdd(nodes)
	local acc = CanonNumeric.newAddAccumulator()
	local out = {}

	for _, n in ipairs(nodes) do
		if Util.isNum(n) then
			CanonNumeric.handleIntegerAdd(acc, n, out)

		elseif Util.isRat(n) then
			CanonNumeric.handleRationalAdd(acc, n, out)

		else
			table_insert(out, n)
		end
	end

	CanonNumeric.accFlush(acc, out)
	return out
end

-- Combine numeric factors in multiplication
-- Also combine repeated variables into powers: a*a*n*n -> a^2 * n^2
function CanonAlgebra.combineMul(nodes)
	local acc = CanonNumeric.newMulAccumulator()
	local accExp = {}
	local others = {}

	for _, n in ipairs(nodes) do
		if Util.isNum(n) then
			CanonNumeric.handleIntegerMul(acc, n, others)

		elseif Util.isRat(n) then
			CanonNumeric.handleRationalMul(acc, n, others)

		else
			CanonAlgebra.mulAccSymbol(accExp, n, others)
		end
	end

	local out = {}

	-- emit coefficient
	local collapseToZero = CanonAlgebra.mulEmitCoefficient(acc, out, (#others > 0 or next(accExp) ~= nil))
	if collapseToZero then
		return { Node.Num("0") }
	end

	-- emit symbolic powers
	CanonAlgebra.mulEmitSymbolic(accExp, out)

	-- emit other factors
	for _, n in ipairs(others) do
		table_insert(out, n)
	end

	-- sort deterministically
	table_sort(out, function(a, b)
		return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
	end)

	-- collapse repeated non-variable factors
	return CanonAlgebra.mulCollapseRepeats(out)
end

-- Returns a canonical monomial descriptor:
-- {
--     coeff = { num = <int>, den = <int> },
--     vars  = { x = 2, y = 1, ["const:pi"] = 1 }
-- }
function CanonAlgebra.monomialKey(node)
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

		if Util.isVar(node.left) then
			return {
				coeff = { num = 1, den = 1 },
				vars  = { [node.left.name] = exp }
			}
		elseif Util.isConst(node.left) then
			return {
				coeff = { num = 1, den = 1 },
				vars  = { ["const:" .. node.left.name] = exp }
			}
		end
	end

	-- Multiplication: combine recursively
	if Util.isOp(node) and node.op == "*" then
		local left  = CanonAlgebra.monomialKey(node.left)
		local right = CanonAlgebra.monomialKey(node.right)

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

-- Buckets symbolic monomials by variable signature; returns { buckets, others }.
function CanonAlgebra.bucketMonomials(nodes)
	local buckets = {}
	local others = {}

	for _, n in ipairs(nodes) do
		local m = CanonAlgebra.monomialKey(n)

		-- Not a symbolic monomial → leave it alone
		if not m or next(m.vars) == nil then
			table_insert(others, n)
		else
			-- Build canonical variable signature
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
					vars  = table.clone(m.vars)
				}
			else
				buckets[key].coeff = CanonNumeric.ratAdd(buckets[key].coeff, m.coeff)
			end
		end
	end

	return buckets, others
end

-- Rebuilds a symbolic monomial AST from a bucket { coeff, vars }.
function CanonAlgebra.rebuildMonomial(bucket)
	if CanonNumeric.ratIsZero(bucket.coeff) then
		return nil
	end

	local factors = {}

	-- symbolic factors
	local names = {}
	for name,_ in pairs(bucket.vars) do table_insert(names, name) end
	table_sort(names)

	for _, name in ipairs(names) do
		local exp = bucket.vars[name]
		local base = Util.buildSymbol(name)

		if exp == 1 then
			table_insert(factors, base)
		else
			table_insert(factors, Node.Op("^", base, Node.Num(tostring(exp))))
		end
	end

	-- numeric coefficient
	local c = bucket.coeff
	if not CanonNumeric.ratIsOne(c) then
		if c.den == 1 then
			table_insert(factors, 1, Node.Num(tostring(c.num)))
		else
			table_insert(factors, 1, Node.Rat(c.num, c.den))
		end
	end

	-- canonical sort
	table_sort(factors, function(a, b)
		return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
	end)

	-- fold into left-associative product
	local term = factors[1]
	for i = 2, #factors do
		term = Node.Op("*", term, factors[i])
	end

	return term
end

-- Rebuilds all monomials in the bucket table into AST nodes.
function CanonAlgebra.rebuildAllMonomials(buckets)
	local out = {}

	for _, bucket in pairs(buckets) do
		local term = CanonAlgebra.rebuildMonomial(bucket)
		if term then
			table_insert(out, term)
		end
	end

	return out
end

-- Combine like terms: a*x + b*x -> (a+b)*x
function CanonAlgebra.combineLikeTerms(nodes)
	local buckets, others = CanonAlgebra.bucketMonomials(nodes)
	local rebuilt = CanonAlgebra.rebuildAllMonomials(buckets)

	for _, term in ipairs(rebuilt) do
		table_insert(others, term)
	end

	return others
end

return CanonAlgebra