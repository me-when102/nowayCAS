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

-- Repeatedly apply rules until stable
function Rewrite.apply(node, rules)
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

		local pArg = pattern.args[1]
		local nArg = node.args[1]

		return Rewrite._match(pArg, nArg, bindings)
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