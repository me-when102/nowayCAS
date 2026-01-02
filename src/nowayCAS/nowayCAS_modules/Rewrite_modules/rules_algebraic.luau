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

			---------------------------------------------------
			-- Numerator: u^2 + (-1 * v^2)
			---------------------------------------------------
			if num.kind ~= "op" or num.op ~= "+" then
				return nil
			end

			local a = num.left      -- expect u^2
			local neg = num.right   -- expect -1 * v^2

			-- a = u^2
			if a.kind ~= "op" or a.op ~= "^" then return nil end
			if a.right.kind ~= "num" or tonumber(a.right.value) ~= 2 then return nil end
			local u = a.left

			-- neg = -1 * v^2
			local b = matchNeg(neg)
			if not b then print("niled 3.5") return nil end
			if b.kind ~= "op" or b.op ~= "^" then return nil end
			if b.right.kind ~= "num" or tonumber(b.right.value) ~= 2 then return nil end
			local v = b.left

			---------------------------------------------------
			-- Denominator: u + (-1 * v)   OR   (-1 * v) + u
			---------------------------------------------------
			if den.kind ~= "op" or den.op ~= "+" then
				return nil
			end

			local du, dneg

			-- Case 1: u + (-1 * v)
			local dv1 = matchNeg(den.right)
			if dv1 and Util.nodeEquals(den.left, u) then
				du = den.left
				dneg = den.right
			end

			-- Case 2: (-1 * v) + u
			local dv2 = matchNeg(den.left)
			if dv2 and Util.nodeEquals(den.right, u) then
				du = den.right
				dneg = den.left
			end

			if not du then
				return nil
			end

			local dv = matchNeg(dneg)
			if not dv then return nil end
			if not Util.nodeEquals(dv, v) then return nil end
			
			return { u = u, v = v }
		end,

		replace = function(node, m)
			return Node.Op("+", m.u, m.v)
		end
	},
}

return rules_algebraic