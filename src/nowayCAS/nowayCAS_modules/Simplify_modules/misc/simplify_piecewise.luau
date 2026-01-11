local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return function(branches)
	-- branches is already simplified by Simplify.simplify
	local out = {}

	for _, pair in ipairs(branches) do
		local cond = pair[1]
		local expr = pair[2]

		-- prune false branches
		if SimplifyHelpers.isFalse(cond) then
			-- skip
		elseif SimplifyHelpers.isTrue(cond) then
			-- true branch short-circuits everything
			return expr
		else
			table.insert(out, { cond, expr })
		end
	end

	-- no branches left
	if #out == 0 then
		-- piecewise with no valid branches is undefined; return as-is
		return Node.Piecewise({})
	end

	-- if only one branch remains and its condition is true, return expr
	if #out == 1 and SimplifyHelpers.isTrue(out[1][1]) then
		return out[1][2]
	end

	return Node.Piecewise(out)
end