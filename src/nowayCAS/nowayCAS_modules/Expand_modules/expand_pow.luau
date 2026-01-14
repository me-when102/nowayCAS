local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)

local ExpandPow = {}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------

-- Is this node an additive operator?
local function isAddOp(n)
	return n.kind == "op" and (n.op == "+" or n.op == "-")
end

-- Collect additive terms (expand_add already flattened)
local function collectAddTerms(node)
	local terms = {}

	local function collect(n)
		if isAddOp(n) then
			collect(n.left)
			collect(n.right)
		else
			table.insert(terms, n)
		end
	end

	collect(node)
	return terms
end

-- Build a + b + c chain
local function buildAddChain(terms)
	local result = terms[1]
	for i = 2, #terms do
		result = Node.Op("+", result, terms[i])
	end
	return result
end

-- Multiply a list of nodes into a chain
local function buildMulChain(terms)
	local result = terms[1]
	for i = 2, #terms do
		result = Node.Op("*", result, terms[i])
	end
	return result
end

-- Build a^b with constant folding for numeric^numeric
local function makePow(base, exponent)
	if Util.isNumeric(base) and Util.isNumeric(exponent) then
		local b = tonumber(base.value)
		local e = tonumber(exponent.value)

		if b and e and e >= 0 and e == math.floor(e) then
			return Node.Num(tostring(b ^ e))
		end
	end

	return Node.Op("^", base, exponent)
end

-------------------------------------------------------
-- Binomial / multinomial expansion
-- (a + b + c)^n -> sum over all products of terms
-------------------------------------------------------
local function expandAddPower(base, exponent)
	-- Only expand integer literal exponents
	if exponent.kind ~= "num" then
		return Node.Op("^", base, exponent)
	end

	local n = tonumber(exponent.value)
	if not n or n < 0 or n ~= math.floor(n) then
		return Node.Op("^", base, exponent)
	end

	-- n = 0 -> 1
	if n == 0 then
		return Node.Num("1")
	end

	-- n = 1 -> base
	if n == 1 then
		return base
	end

	local terms = collectAddTerms(base)
	local k = #terms

	-- Simple case: 2-term binomial
	if k == 2 then
		local a, b = terms[1], terms[2]
		-- (a + b)^n = sum_{i=0..n} C(n,i) a^(n-i) b^i
		local products = {}

		for i = 0, n do
			local coeff = Node.Num(tostring(Util.binomial(n, i)))
			local factors = {}

			-- a^(n-i)
			if n - i > 0 then
				if n - i == 1 then
					table.insert(factors, a)
				else
					table.insert(factors, makePow(a, Node.Num(tostring(n - i))))
				end
			end

			-- b^i
			if i > 0 then
				if i == 1 then
					table.insert(factors, b)
				else
					table.insert(factors, makePow(b, Node.Num(tostring(i))))
				end
			end

			-- multiply coeff * factors
			local term = coeff
			for _, f in ipairs(factors) do
				term = Node.Op("*", term, f)
			end

			table.insert(products, term)
		end

		return buildAddChain(products)
	end

	-- Multinomial expansion for more than 2 terms
	-- (a + b + c)^n -> sum over all exponent tuples e1+e2+e3=n
	local products = {}

	local function recurse(idx, remaining, exps)
		if idx > k then
			if remaining == 0 then
				-- multinomial coefficient
				local coeff = Util.multinomial(exps)

				local factors = {}
				for i = 1, k do
					local e = exps[i]
					if e > 0 then
						if e == 1 then
							table.insert(factors, terms[i])
						else
							table.insert(factors, makePow(terms[i], Node.Num(tostring(e))))
						end
					end
				end

				local term = Node.Num(tostring(coeff))
				for _, f in ipairs(factors) do
					term = Node.Op("*", term, f)
				end

				table.insert(products, term)
			end
			return
		end

		for e = 0, remaining do
			exps[idx] = e
			recurse(idx + 1, remaining - e, exps)
		end
	end

	recurse(1, n, {})

	return buildAddChain(products)
end

-------------------------------------------------------
-- Main entry point
-------------------------------------------------------

-- Expands the node through power.
function ExpandPow.apply(node)
	-- Recurse first
	if Util.isOp(node) then
		local left  = ExpandPow.apply(node.left)
		local right = ExpandPow.apply(node.right)
		node = Node.Op(node.op, left, right)

		-- Only expand powers
		if node.op == "^" then
			-- Constant folding: numeric^numeric
			if Util.isNumeric(left) and Util.isNumeric(right) then
				local base = tonumber(left.value)
				local exp  = tonumber(right.value)

				-- Only fold integer, non-negative exponents
				if base and exp and exp >= 0 and exp == math.floor(exp) then
					local v = base ^ exp
					return Node.Num(tostring(v))
				end
			end

			-- Case 1: (sum)^n
			if isAddOp(left) then
				return expandAddPower(left, right)
			end

			-- Case 2: (product)^n -> distribute exponent
			if Util.isOp(left) and left.op == "*" and Util.isNum(right) then
				local n = tonumber(right.value)
				if n and n >= 0 and n == math.floor(n) then
					local factors = {}

					-- (a*b*c)^n -> a^n * b^n * c^n
					local function collectMul(n)
						if Util.isOp(n) and n.op == "*" then
							collectMul(n.left)
							collectMul(n.right)
						else
							table.insert(factors, n)
						end
					end

					collectMul(left)

					local powered = {}
					for _, f in ipairs(factors) do
						table.insert(powered, makePow(f, right))
					end

					return buildMulChain(powered)
				end
			end
		end

	elseif Util.isFunc(node) then
		local args = {}
		for i, a in ipairs(node.args) do
			args[i] = ExpandPow.apply(a)
		end
		node = Node.Func(node.name, args)
	end

	return node
end

return ExpandPow