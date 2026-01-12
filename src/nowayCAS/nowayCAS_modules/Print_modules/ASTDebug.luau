local ASTDebug = {}

local Util = require(script.Parent.Parent.Util)
local table_insert = table.insert

-------------------------------------------------------
-- AST Representation Debug
-- Prints the AST.
-------------------------------------------------------

-- Returns a shallow table representation of the AST (safe for printing / tests)
local function nodeToTable(node)
	if not node then return nil end

	local t = { kind = node.kind }

	if Util.isNum(node) then
		t.value = node.value

	elseif Util.isVar(node) then
		t.name = node.name

	elseif Util.isConst(node) then
		t.name = node.name

	elseif Util.isComplex(node) then
		t.real = nodeToTable(node.real)
		t.imag = nodeToTable(node.imag)

	elseif Util.isFunc(node) then
		t.name = node.name
		t.args = {}
		for i, a in ipairs(node.args) do
			t.args[i] = nodeToTable(a)
		end

	elseif Util.isOp(node) then
		t.op = node.op
		t.left = nodeToTable(node.left)
		t.right = nodeToTable(node.right)

	elseif Util.isPiecewise(node) then
		t.branches = {}
		for i, pair in ipairs(node.branches) do
			t.branches[i] = {
				cond = nodeToTable(pair[1]),
				expr = nodeToTable(pair[2]),
			}
		end
	end

	return t
end

-- Build an indented, human-readable representation
local function nodeToIndented(node, level, out)
	level = level or 0
	local indent = string.rep("  ", level)

	if not node then
		table_insert(out, indent .. "<nil>")

	elseif Util.isNum(node) then
		table_insert(out, indent .. ("Num value=%s"):format(tostring(node.value)))

	elseif Util.isVar(node) then
		table_insert(out, indent .. ("Var name=%s"):format(tostring(node.name)))

	elseif Util.isConst(node) then
		table_insert(out, indent .. ("Const name=%s"):format(tostring(node.name)))

	elseif Util.isComplex(node) then
		table_insert(out, indent .. "Complex")
		nodeToIndented(node.real, level + 1, out)
		nodeToIndented(node.imag, level + 1, out)

	elseif Util.isFunc(node) then
		table_insert(out, indent .. ("Func name=%s"):format(tostring(node.name)))
		for _, a in ipairs(node.args) do
			nodeToIndented(a, level + 1, out)
		end

	elseif Util.isOp(node) then
		table_insert(out, indent .. ("Op %s"):format(tostring(node.op)))
		nodeToIndented(node.left, level + 1, out)
		nodeToIndented(node.right, level + 1, out)

	elseif Util.isPiecewise(node) then
		table_insert(out, indent .. "Piecewise")
		for _, pair in ipairs(node.branches) do
			table_insert(out, indent .. "  Branch:")
			nodeToIndented(pair[1], level + 2, out)
			nodeToIndented(pair[2], level + 2, out)
		end

	else
		table_insert(out, indent .. ("<unknown kind=%s>"):format(tostring(node.kind)))
	end
end

-- Returns a table and an indented string
function ASTDebug._toASTRepresentation(root)
	local raw = nodeToTable(root)
	local lines = {}
	nodeToIndented(root, 0, lines)
	local indented = table.concat(lines, "\n")
	return {
		raw = raw,
		indented = indented,
	}
end

return ASTDebug