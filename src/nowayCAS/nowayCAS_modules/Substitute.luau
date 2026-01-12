local Substitute = {}

local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)

-------------------------------------------------------
-- Substitute
-- Performs structural substitution on AST nodes.
-- Example: substitute(x^2 + 3x, { x = (y+1) })
-------------------------------------------------------

-- Substitute variables according to a map:
--   { x = Node(...), y = Node(...), ... }
function Substitute.apply(node, map)

	-- Numbers and rationals unchanged
	if Util.isNumeric(node) then
		return node
	end

	-- Variable replacement
	if Util.isVar(node) then
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
	if Util.isConst(node) then
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

	-- Operators: recurse into children
	if Util.isOp(node) then
		local left = Substitute.apply(node.left, map)
		local right = Substitute.apply(node.right, map)
		return Node.Op(node.op, left, right)
	end

	-- Complex numbers: recurse into real and imag
	if Util.isComplex(node) then
		local newReal = Substitute.apply(node.real, map)
		local newImag = Substitute.apply(node.imag, map)

		-- If nothing changed, return original node
		if newReal == node.real and newImag == node.imag then
			return node
		end

		return Node.Complex(newReal, newImag)
	end

	-- Functions: recurse into argument
	if Util.isFunc(node) then
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

	-- Piecewise: Substitute inside branches.
	if Util.isPiecewise(node) then
		local newBranches = {}
		local changed = false

		for i, pair in ipairs(node.branches) do
			local cond = Substitute.apply(pair[1], map)
			local expr = Substitute.apply(pair[2], map)

			if cond ~= pair[1] or expr ~= pair[2] then
				changed = true
			end

			newBranches[i] = { cond, expr }
		end

		if not changed then
			return node
		end

		return Node.Piecewise(newBranches)
	end

	error("Substitute: Unknown node kind '" .. tostring(node.kind) .. "'")
end

-- The Substitute sub-library.
return Substitute