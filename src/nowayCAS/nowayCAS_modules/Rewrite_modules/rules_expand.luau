local rules_expand = {}

local table_insert = table.insert
local table_remove = table.remove

local Node = require(script.Parent.Parent.Node)

-- Checks if the node's operator is op.
local function isAssocOp(node, op)
	return node.kind == "op" and node.op == op
end

-- Gets the children of the node (left and right).
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

-- Rebuild assication.
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
	
	-------------------------------------------------------
	-- (a + b + ...)^n -> sum of all n-fold products
	-------------------------------------------------------
	{
		op = "^",
		match = function(node)
			if node.left.kind == "op" and node.left.op == "+" then
				if node.right.kind == "num" then
					local n = tonumber(node.right.value)
					if n and n >= 2 then
						return {
							terms = childrenOf(node.left, "+"),
							power = n,
						}
					end
				end
			end
			return nil
		end,

		replace = function(node, m)
			local terms = m.terms
			local n = m.power

			-- start with the neutral element for multiplication
			local products = { Node.Num("1") }

			for _ = 1, n do
				local newProducts = {}
				for _, p in ipairs(products) do
					for _, t in ipairs(terms) do
						table_insert(newProducts, Node.Op("*", p, t))
					end
				end
				products = newProducts
			end

			return rebuildAssoc("+", products)
		end
	},

	-------------------------------------------------------
	-- Rule: (a + b)(c + d) -> a*c + a*d + b*c + b*d
	-------------------------------------------------------
	{
		op = "*",
		match = function(factors)
			-- find two additive factors
			local sums = {}
			for i, f in ipairs(factors) do
				if isAssocOp(f, "+") then
					table_insert(sums, { index = i, terms = childrenOf(f, "+") })
				end
			end

			-- need at least two sums to expand
			if #sums < 2 then return nil end

			-- expand the FIRST TWO sums found
			return {
				i = sums[1].index,
				j = sums[2].index,
				A = sums[1].terms,
				B = sums[2].terms,
			}
		end,

		replace = function(node, m)
			local factors = childrenOf(node, "*")

			-- remove the two sums
			local i, j = m.i, m.j
			if i > j then i, j = j, i end
			table_remove(factors, j)
			table_remove(factors, i)

			-- build all pairwise products
			local products = {}
			for _, a in ipairs(m.A) do
				for _, b in ipairs(m.B) do
					table_insert(products, Node.Op("*", a, b))
				end
			end

			-- insert the expanded sum
			table_insert(factors, rebuildAssoc("+", products))

			return rebuildAssoc("*", factors)
		end
	},
	-------------------------------------------------------
	-- Rule: a * (b + c) -> a*b + a*c
	-------------------------------------------------------
	{
		op = "*",
		match = function(factors)
			for i, a in ipairs(factors) do
				for j, sum in ipairs(factors) do
					if i ~= j and isAssocOp(sum, "+") then
						local kids = childrenOf(sum, "+")
						if #kids == 2 then
							return {
								i = i, j = j,
								a = a,
								b = kids[1],
								c = kids[2],
							}
						end
					end
				end
			end
			return nil
		end,

		replace = function(node, m)
			local factors = childrenOf(node, "*")

			-- remove matched factors
			local i, j = m.i, m.j
			if i > j then i, j = j, i end
			table_remove(factors, j)
			table_remove(factors, i)

			-- build a*b + a*c
			local expanded = Node.Op("+",
				Node.Op("*", m.a, m.b),
				Node.Op("*", m.a, m.c)
			)

			table_insert(factors, expanded)
			return rebuildAssoc("*", factors)
		end
	},

	-------------------------------------------------------
	-- Rule: (a + b) * c -> a*c + b*c
	-------------------------------------------------------
	{
		op = "*",
		match = function(factors)
			for i, sum in ipairs(factors) do
				if isAssocOp(sum, "+") then
					local kids = childrenOf(sum, "+")
					if #kids == 2 then
						for j, c in ipairs(factors) do
							if i ~= j then
								return {
									i = i, j = j,
									a = kids[1],
									b = kids[2],
									c = c,
								}
							end
						end
					end
				end
			end
			return nil
		end,

		replace = function(node, m)
			local factors = childrenOf(node, "*")

			local i, j = m.i, m.j
			if i > j then i, j = j, i end
			table_remove(factors, j)
			table_remove(factors, i)

			local expanded = Node.Op("+",
				Node.Op("*", m.a, m.c),
				Node.Op("*", m.b, m.c)
			)

			table_insert(factors, expanded)
			return rebuildAssoc("*", factors)
		end
	},
}

return rules_expand