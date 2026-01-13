local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)

local ExpandSign = {}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------

-- Is this node an additive operator?
local function isAddOp(n)
	return n.kind == "op" and (n.op == "+" or n.op == "-")
end

-- Collect signed terms from an additive chain.
-- Example:
--   a - b + c  ->  { {a, +1}, {b, -1}, {c, +1} }
local function collectTerms(node, sign, out)
	if isAddOp(node) then
		collectTerms(node.left, sign, out)
		local rightSign = (node.op == "+") and sign or -sign
		collectTerms(node.right, rightSign, out)
	else
		table.insert(out, { node = node, sign = sign })
	end
end

-- Build an additive chain from signed terms.
local function buildAddChain(terms)
	local result = nil

	for _, t in ipairs(terms) do
		local n = t.node
		if t.sign == -1 then
			n = Node.Op("*", Node.Num("-1"), n)
		end

		if not result then
			result = n
		else
			result = Node.Op("+", result, n)
		end
	end

	return result
end

-------------------------------------------------------
-- expandUnaryMinus
-- Handles:  -(a + b), -(a - b), -(-x), -(a + b - c)
-------------------------------------------------------
local function expandUnaryMinus(node)
	-- unary minus is represented as: (-1) * expr
	if Util.isOp(node) and node.op == "*" and Util.isNegOne(node.left) then
		local expr = node.right

		-- -(a + b) -> -a - b
		if isAddOp(expr) then
			local terms = {}
			collectTerms(expr, -1, terms)
			return buildAddChain(terms)
		end

		-- -(-x) -> x
		if Util.isOp(expr) and expr.op == "*" and Util.isNegOne(expr.left) then
			return expr.right
		end
	end

	return node
end

-------------------------------------------------------
-- expandBinaryMinus
-- Handles:  x - (a + b), x - (a - b)
-------------------------------------------------------
local function expandBinaryMinus(node)
	if Util.isOp(node) and node.op == "-" then
		local left = node.left
		local right = node.right

		if isAddOp(right) then
			local terms = {}

			-- left stays positive
			table.insert(terms, { node = left, sign = 1 })

			-- flip all signs of right
			collectTerms(right, -1, terms)

			return buildAddChain(terms)
		end
	end

	return node
end

-------------------------------------------------------
-- Main entry point for this phase
-------------------------------------------------------

-- Expands the node through signs.
function ExpandSign.apply(node)
	-- Recurse first
	if Util.isOp(node) then
		local left  = ExpandSign.apply(node.left)
		local right = ExpandSign.apply(node.right)
		node = Node.Op(node.op, left, right)
	elseif Util.isFunc(node) then
		local args = {}
		for i, a in ipairs(node.args) do
			args[i] = ExpandSign.apply(a)
		end
		node = Node.Func(node.name, args)
	end

	-- Apply unary minus expansion
	local out = expandUnaryMinus(node)
	if out ~= node then
		return out
	end

	-- Apply binary minus expansion
	out = expandBinaryMinus(node)
	if out ~= node then
		return out
	end

	return node
end

return ExpandSign