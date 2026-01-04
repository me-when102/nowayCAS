local rules_expand = {}

local Node = require(script.Parent.Parent.Node)
local Rewrite = require(script.Parent)
local R = Rewrite.R
local RF = Rewrite.RF

local table_insert = table.insert

-------------------------------------------------------
-- Expansion
-------------------------------------------------------

local function isAssocOp(node, op)
	return node.kind == "op" and node.op == op
end

local function childrenOf(node, op)
	if isAssocOp(node, op) then
		local items = {}
		local function collect(n)
			if isAssocOp(n, op) then
				collect(n.left); collect(n.right)
			else
				table_insert(items, n)
			end
		end
		collect(node)
		return items
	else
		return { node }
	end
end

local function rebuildAssoc(op, items)
	if #items == 0 then
		error("rebuildAssoc: empty")
	end
	local acc = items[1]
	for i = 2, #items do
		acc = Node.Op(op, acc, items[i])
	end
	return acc
end

rules_expand = {
	-- (a + b + ...)^n -> sum of all n-fold products
	RF("(_sum)^_n", function(node, m)
		local terms = childrenOf(m._sum, "+")
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

		return rebuildAssoc("+", products)
	end),

	-- (A + B + ...) * (C + D + ...) → all pairwise products
	RF("_x * _y", function(node, m)
		local left  = node.left
		local right = node.right

		-- Only expand if BOTH sides are sums
		if not (left.kind == "op" and left.op == "+") then return node end
		if not (right.kind == "op" and right.op == "+") then return node end

		local leftTerms  = childrenOf(left, "+")
		local rightTerms = childrenOf(right, "+")

		local out = {}
		for _, a in ipairs(leftTerms) do
			for _, b in ipairs(rightTerms) do
				table_insert(out, Node.Op("*", a, b))
			end
		end

		return rebuildAssoc("+", out)
	end)
}

return rules_expand