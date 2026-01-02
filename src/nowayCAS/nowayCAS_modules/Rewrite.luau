local Rewrite = {}

local Node = require(script.Parent.Node)
local Canon = require(script.Parent.Canon)
local Util = require(script.Parent.Util)

local table_remove = table.remove
local table_insert = table.insert

local ipairs = ipairs

-------------------------------------------------------
-- Rewrite
-------------------------------------------------------

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

-- Rebuild association.
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

-- RULES DO SOMETHING!!!!

-- Expansion rules
local expandRules = {

	-- (a + b + ...)^n -> sum of all n-fold products
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


-- Try to apply one rule to a node
function Rewrite._applyRule(node, rule)
	local bindings = Rewrite._match(rule.pattern, node)
	if not bindings then
		return node, false
	end
	return rule.replace(bindings), true
end

-- Try all rules once
function Rewrite._rewrite(node, rules)
	-- Recurse into children first
	if node.kind == "op" then
		local left, changedL = Rewrite._rewrite(node.left, rules)
		local right, changedR = Rewrite._rewrite(node.right, rules)

		if changedL or changedR then
			node = Node.Op(node.op, left, right)
		end
	end

	-- Try rules at this node
	if node.kind == "op" then
		for _, rule in ipairs(rules) do
			if rule.op == node.op then
				local match

				if node.op == "+" or node.op == "*" then
					match = rule.match(childrenOf(node, node.op))
				else
					match = rule.match(node)
				end

				if match then
					return rule.replace(node, match), true
				end
			end
		end
	end

	return node, false
end

local function preprocessImplicitMul(node)
	if node.kind == "func" and node.name:match("^[a-zA-Z]$") then  -- heuristic: single-letter vars
		-- Treat a(b + c) as a * (b + c)
		return Node.Op("*", Node.Var(node.name), preprocessImplicitMul(node.arg))
	elseif node.kind == "op" then
		return Node.Op(node.op,
			preprocessImplicitMul(node.left),
			preprocessImplicitMul(node.right)
		)
	elseif node.kind == "func" then
		return Node.Func(node.name, preprocessImplicitMul(node.arg))
	else
		return node
	end
end

-- Repeatedly apply rules until stable
function Rewrite.apply(node, rules)
	node = preprocessImplicitMul(node)

	while true do
		local next, changed = Rewrite._rewrite(node, rules)
		if not changed then
			return Canon.canonical(node)
		end
		node = next
	end
end

function Rewrite._match(pattern, node, bindings)
	bindings = bindings or {}
	-- Pattern variable (e.g., Node.Var("a") used as a wildcard)
	if pattern.kind == "var" and pattern.name:match("^_") then
		local key = pattern.name
		if bindings[key] then
			if Util.nodeEquals(bindings[key], node) then
				return bindings
			else
				return nil
			end
		else
			bindings[key] = node
			return bindings
		end
	end

	-- Numeric wildcard (e.g., Node.Num("_n"))
	if pattern.kind == "num" and type(pattern.value) == "string" and pattern.value:match("^_") then
		local key = pattern.value
		if bindings[key] then
			if Util.nodeEquals(bindings[key], node) then
				return bindings
			else
				return nil
			end
		else
			-- only bind to numeric nodes
			if node.kind ~= "num" then return nil end
			bindings[key] = node
			return bindings
		end
	end

	-- Exact match
	if pattern.kind ~= node.kind then return nil end

	if pattern.kind == "num" then
		return (pattern.value == node.value) and bindings or nil
	end

	if pattern.kind == "var" then
		return (pattern.name == node.name) and bindings or nil
	end

	if pattern.kind == "func" then
		if pattern.name ~= node.name then return nil end
		return Rewrite._match(pattern.arg, node.arg, bindings)
	end

	if pattern.kind == "op" then
		if pattern.op ~= node.op then return nil end

		-- Commutative operators: try both orders
		if pattern.op == "+" or pattern.op == "*" then
			-- Try normal order
			local b1 = Rewrite._match(pattern.left, node.left, table.clone(bindings))
			if b1 then
				local b2 = Rewrite._match(pattern.right, node.right, b1)
				if b2 then return b2 end
			end

			-- Try swapped order
			local b3 = Rewrite._match(pattern.left, node.right, table.clone(bindings))
			if b3 then
				local b4 = Rewrite._match(pattern.right, node.left, b3)
				if b4 then return b4 end
			end

			return nil
		end

		-- Non-commutative: normal matching
		bindings = Rewrite._match(pattern.left, node.left, bindings)
		if not bindings then return nil end
		return Rewrite._match(pattern.right, node.right, bindings)
	end
end

-- The Rewrite sub-library
return Rewrite