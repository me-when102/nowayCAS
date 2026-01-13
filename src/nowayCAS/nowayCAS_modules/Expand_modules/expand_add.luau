local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)

local ExpandAdd = {}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------

-- Is this node an additive operator?
local function isAddOp(n)
	return n.kind == "op" and n.op == "+"
end

-- Collect additive terms into a flat list.
-- Signs are already normalized by expand_sign.
local function collectTerms(node, out)
	if isAddOp(node) then
		collectTerms(node.left, out)
		collectTerms(node.right, out)
	else
		table.insert(out, node)
	end
end

-- Rebuild a flat additive chain from a list of nodes.
local function buildAddChain(terms)
	local result = terms[1]
	for i = 2, #terms do
		result = Node.Op("+", result, terms[i])
	end
	return result
end

-------------------------------------------------------
-- Main entry point
-------------------------------------------------------

-- Expands the node through addition.
function ExpandAdd.apply(node)
	-- Recurse first
	if Util.isOp(node) then
		local left  = ExpandAdd.apply(node.left)
		local right = ExpandAdd.apply(node.right)
		node = Node.Op(node.op, left, right)
	elseif Util.isFunc(node) then
		local args = {}
		for i, a in ipairs(node.args) do
			args[i] = ExpandAdd.apply(a)
		end
		node = Node.Func(node.name, args)
	end

	-- Only flatten additive chains
	if isAddOp(node) then
		local terms = {}
		collectTerms(node, terms)

		-- If flattening changed structure, rebuild
		if #terms > 1 then
			return buildAddChain(terms)
		end
	end

	return node
end

return ExpandAdd