local CanonStruct = {}
local Util = require(script.Parent.Parent.Util)

local table_insert = table.insert

-- Flatten associative operators.
function CanonStruct.flatten(op, items)
	local out = {}

	local function add(n)
		if Util.isOp(n) and n.op == op then
			add(n.left)
			add(n.right)
		else
			table_insert(out, n)
		end
	end

	for _, n in ipairs(items) do add(n) end
	return out
end

return CanonStruct