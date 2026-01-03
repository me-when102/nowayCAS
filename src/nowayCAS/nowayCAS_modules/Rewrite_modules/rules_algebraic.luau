local rules_algebraic = {}

local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)

-------------------------------------------------------
-- Algebraic Simplifications (Factorization, Cancellation,
-- Rational simplification, Structural rewrites)
-------------------------------------------------------

-- Check if the node is basically a unary minus
local function matchNeg(node)
	-- (-1) * X
	if node.kind == "op" and node.op == "*" then
		if node.left.kind == "num" and node.left.value == "-1" then
			return node.right
		end
		if node.right.kind == "num" and node.right.value == "-1" then
			return node.left
		end
	end
	return nil
end

rules_algebraic.simplify = {
	---------------------------------------------------
	-- Difference of squares:
	-- (u^2 - v^2) / (u - v)  ->  u + v
	---------------------------------------------------
	{
		op = "/",
		match = function(node)
			local num = node.left
			local den = node.right

			-- Extract the two terms in numerator (should be ±u^2 and ±v^2)
			if num.kind ~= "op" or num.op ~= "+" then return nil end

			local term1, term2 = num.left, num.right

			-- Helper to extract base and sign from ±base^2
			local function extractSquare(term)
				local sign = 1
				local base

				-- Case: + (base^2)
				if term.kind == "op" and term.op == "^" and term.right.kind == "num" and tonumber(term.right.value) == 2 then
					base = term.left
					-- Case: - (base^2) -> either unary or (* -1 base^2)
				else
					local negated = matchNeg(term)
					if negated and negated.kind == "op" and negated.op == "^" and negated.right.kind == "num" and tonumber(negated.right.value) == 2 then
						base = negated.left
						sign = -1
					else
						return nil
					end
				end

				return base, sign
			end

			local u, signU = extractSquare(term1)
			local v, signV = extractSquare(term2)
			if not u then
				u, signU = extractSquare(term2)
				v, signV = extractSquare(term1)
			end
			if not u or not v then return nil end

			-- We need one + and one -
			if signU == signV then return nil end

			-- Determine which is positive
			local posBase = signU == 1 and u or v
			local negBase = signU == 1 and v or u

			-- Now check denominator: should be posBase + (-negBase)
			local expectedDen
			if den.kind == "op" and den.op == "+" then
				local d1, d2 = den.left, den.right
				local negPart = matchNeg(d2) or matchNeg(d1)
				local posPart = (matchNeg(d2) and den.left) or (matchNeg(d1) and den.right) or nil

				if posPart and negPart and Util.nodeEquals(posPart, posBase) and Util.nodeEquals(negPart, negBase) then
					return { u = posBase, v = negBase }
				end
			end

			return nil
		end,
		replace = function(node, m)
			return Node.Op("+", m.u, m.v)
		end
	},
}

return rules_algebraic