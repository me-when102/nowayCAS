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

return RewriteRuleHelpers