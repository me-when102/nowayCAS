local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)

local ExpandMul = {}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------

-- Is this node an additive operator?
local function isAddOp(n)
	return n.kind == "op" and (n.op == "+" or n.op == "-")
end

-- Collect additive terms into a flat list (expand_add already flattened)
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

-------------------------------------------------------
-- Distribute multiplication
-------------------------------------------------------
local function distribute(left, right)
	local leftTerms  = collectAddTerms(left)
	local rightTerms = collectAddTerms(right)

	-- If neither side is additive, no distribution needed
	if #leftTerms == 1 and #rightTerms == 1 then
		return Node.Op("*", left, right)
	end

	-- Build all pairwise products
	local products = {}

	for _, a in ipairs(leftTerms) do
		for _, b in ipairs(rightTerms) do
			table.insert(products, Node.Op("*", a, b))
		end
	end

	return buildAddChain(products)
end

-------------------------------------------------------
-- Main entry point
-------------------------------------------------------

-- Expands the node through multiplication.
function ExpandMul.apply(node)
	-- Recurse first
	if Util.isOp(node) then
		local left  = ExpandMul.apply(node.left)
		local right = ExpandMul.apply(node.right)
		node = Node.Op(node.op, left, right)

		-- Only distribute for multiplication
		if node.op == "*" then
			return distribute(left, right)
		end

	elseif Util.isFunc(node) then
		local args = {}
		for i, a in ipairs(node.args) do
			args[i] = ExpandMul.apply(a)
		end
		node = Node.Func(node.name, args)
	end

	return node
end

return ExpandMul