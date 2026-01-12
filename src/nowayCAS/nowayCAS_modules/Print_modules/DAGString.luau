local DAGString = {}

local Util = require(script.Parent.Parent.Util)
local String = require(script.Parent.String)
local table_insert = table.insert

-------------------------------------------------------
-- DAG-Aware Pretty Printer
-- Detects shared subexpressions and names them (t1, t2, ...)
-------------------------------------------------------

-- Count references to each node in the DAG
local function countRefs(root)
	local counts = {}
	local order = {}

	local function visit(node)
		if counts[node] then
			counts[node] += 1
			return
		end

		counts[node] = 1
		table_insert(order, node)

		if Util.isOp(node) then
			visit(node.left)
			visit(node.right)

		elseif Util.isFunc(node) then
			-- functions have *args*, not arg
			for _, a in ipairs(node.args) do
				visit(a)
			end

		elseif Util.isComplex(node) then
			visit(node.real)
			visit(node.imag)

		elseif Util.isPiecewise(node) then
			for _, pair in ipairs(node.branches) do
				visit(pair[1])
				visit(pair[2])
			end
		end
	end

	visit(root)
	return counts, order
end

-- Converts the node into a DAG string.
function DAGString._toDAGString(root)
	local counts, order = countRefs(root)

	-- Assign names to repeated nodes
	local names = {}
	local counter = 1
	for _, node in ipairs(order) do
		if counts[node] > 1 then
			names[node] = "t" .. counter
			counter += 1
		end
	end

	local out = {}

	-- Emit definitions for repeated subexpressions
	for _, node in ipairs(order) do
		local name = names[node]
		if name then
			table_insert(out, name .. " = " .. String._toString(node))
		end
	end

	-- Emit final expression
	table_insert(out, "result = " .. String._toString(root))

	return table.concat(out, "\n")
end

return DAGString