local RewriteRuleHelpers = {}

local Node = require(script.Parent.Parent.Node)

function RewriteRuleHelpers.isAssocOp(node, op)
	return node.kind == "op" and node.op == op
end

function RewriteRuleHelpers.childrenOf(node, op)
	if RewriteRuleHelpers.isAssocOp(node, op) then
		local items = {}
		local function collect(n)
			if RewriteRuleHelpers.isAssocOp(n, op) then
				collect(n.left); collect(n.right)
			else
				table.insert(items, n)
			end
		end
		collect(node)
		return items
	else
		return { node }
	end
end

function RewriteRuleHelpers.rebuildAssoc(op, items)
	if #items == 0 then
		error("rebuildAssoc: empty")
	end
	local acc = items[1]
	for i = 2, #items do
		acc = Node.Op(op, acc, items[i])
	end
	return acc
end

function RewriteRuleHelpers.rebuildOp(op, items)
	-- Identity elements for empty lists
	if #items == 0 then
		if op == "+" then
			return Node.Num("0")
		elseif op == "*" then
			return Node.Num("1")
		else
			-- Non-AC ops shouldn't hit this, but fallback
			return nil
		end
	end

	-- Single element → return directly
	if #items == 1 then
		return items[1]
	end

	-- Left-associative fold:
	-- (((a op b) op c) op d)
	local node = items[1]
	for i = 2, #items do
		node = Node.Op(op, node, items[i])
	end

	return node
end

return RewriteRuleHelpers