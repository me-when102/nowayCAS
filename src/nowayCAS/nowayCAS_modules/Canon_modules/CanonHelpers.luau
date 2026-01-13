local CanonHelpers = {}

local Util = require(script.Parent.Parent.Util)

local table_insert = table.insert
local ipairs = ipairs

-- Returns the canonical structural idenitity of a node.
function CanonHelpers.canonicalKey(node)
	if Util.isNum(node) then
		return "num:" .. node.value

	elseif Util.isRat(node) then
		return "rat:" .. node.num .. "/" .. node.den

	elseif Util.isVar(node) then
		return "var:" .. node.name

	elseif Util.isConst(node) then
		return "const:" .. node.name

	elseif Util.isComplex(node) then
		return "complex(" 
			.. CanonHelpers.canonicalKey(node.real) .. "," 
			.. CanonHelpers.canonicalKey(node.imag) .. ")"

	elseif Util.isFunc(node) then
		local parts = { "func:", node.name, "(" }
		for i, arg in ipairs(node.args) do
			if i > 1 then table_insert(parts, ",") end
			table_insert(parts, CanonHelpers.canonicalKey(arg))
		end
		table_insert(parts, ")")
		return table.concat(parts)

	elseif Util.isOp(node) then
		return "op:" .. node.op .. "("
			.. CanonHelpers.canonicalKey(node.left) .. ","
			.. CanonHelpers.canonicalKey(node.right) .. ")"

	elseif Util.isPiecewise(node) then
		local parts = { "piecewise(" }
		for i, branch in ipairs(node.branches) do
			if i > 1 then table_insert(parts, ",") end
			table_insert(parts, CanonHelpers.canonicalKey(branch.cond))
			table_insert(parts, ":")
			table_insert(parts, CanonHelpers.canonicalKey(branch.expr))
		end
		table_insert(parts, ")")
		return table.concat(parts)

	else
		return node.kind or "?"
	end
end

return CanonHelpers