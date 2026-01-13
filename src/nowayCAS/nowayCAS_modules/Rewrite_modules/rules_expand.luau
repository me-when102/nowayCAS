local rules_expand = {}

local Node = require(script.Parent.Parent.Node)
local Rewrite = require(script.Parent)
local RewriteRuleHelpers = require(script.Parent.RewriteRuleHelpers)
local R = Rewrite.R
local RF = Rewrite.RF

local table_insert = table.insert

-------------------------------------------------------
-- Expansion
-------------------------------------------------------

rules_expand = {
	-- (a + b + ...)^n -> sum of all n-fold products
	RF("(_sum)^_n", function(node, m)
		local terms = RewriteRuleHelpers.childrenOf(m._sum, "+")
		local n = tonumber(m._n.value)
		if not n or n < 2 then
			return node
		end

		local products = { Node.Num(1) }

		for _ = 1, n do
			local new = {}
			for _, p in ipairs(products) do
				for _, t in ipairs(terms) do
					table_insert(new, Node.Op("*", p, t))
				end
			end
			products = new
		end

		return RewriteRuleHelpers.rebuildAssoc("+", products)
	end),

	-- (A + B + ...) * (C + D + ...) -> all pairwise products
	RF("_x * _y", function(node, m)
		local left = node.left
		local right = node.right

		-- Collect terms with signs from an additive chain (+ or -)
		local function getSignedTerms(expr)
			local terms = {}
			local function collect(n, sign)  -- sign: 1 or -1
				if n.kind == "op" and (n.op == "+" or n.op == "-") then
					collect(n.left, sign)
					local rightSign = (n.op == "+") and sign or -sign
					collect(n.right, rightSign)
				else
					-- Leaf term
					local term = n
					if sign == -1 then
						-- Wrap in unary minus: 0 - term
						term = Node.Op("-", Node.Num("0"), n)
					end
					table.insert(terms, term)
				end
			end
			collect(expr, 1)
			return terms
		end

		local leftTerms = getSignedTerms(left)
		local rightTerms = getSignedTerms(right)

		-- If neither side has multiple terms, no distribution needed
		if #leftTerms <= 1 and #rightTerms <= 1 then
			return node
		end

		local products = {}
		for _, a in ipairs(leftTerms) do
			for _, b in ipairs(rightTerms) do
				table.insert(products, Node.Op("*", a, b))
			end
		end

		-- Rebuild as associative +
		if #products == 0 then
			return Node.Num(0)
		end
		local result = products[1]
		for i = 2, #products do
			result = Node.Op("+", result, products[i])
		end
		return result
	end),
}

return rules_expand