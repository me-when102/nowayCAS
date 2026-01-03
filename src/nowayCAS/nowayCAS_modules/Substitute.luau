local Substitute = {}

local Node = require(script.Parent.Node)

-------------------------------------------------------
-- Substitute
-- Performs structural substitution on AST nodes.
-- Example: substitute(x^2 + 3x, { x = (y+1) })
-------------------------------------------------------

-- Substitute variables according to a map:
--   { x = Node(...), y = Node(...), ... }
function Substitute.apply(node, map)
	local kind = node.kind

	-- Variable replacement
	if kind == "var" then
		local repl = map[node.name]
		if repl then
			-- If replacement is an expression, use its AST
			if repl.node then
				return repl.node
			end
			
			return repl
		else
			return node
		end
	end
	
	-- Constants: allow substitution just like variables
	if kind == "const" then
		local repl = map[node.name]
		if repl then
			if repl.node then
				return repl.node
			end
			return repl
		else
			return node
		end
	end

	-- Numbers unchanged
	if kind == "num" then
		return node
	end

	-- Functions: recurse into argument
	if kind == "func" then
		local newArgs = {}
		local changed = false

		for i, a in ipairs(node.args) do
			local sa = Substitute.apply(a, map)
			newArgs[i] = sa
			if sa ~= a then
				changed = true
			end
		end

		if not changed then
			return node
		end

		return Node.Func(node.name, newArgs)
	end

	-- Operators: recurse into children
	if kind == "op" then
		local left = Substitute.apply(node.left, map)
		local right = Substitute.apply(node.right, map)
		return Node.Op(node.op, left, right)
	end

	error("Substitute: Unknown node kind '" .. tostring(kind) .. "'")
end

-- The Substitute sub-library.
return Substitute