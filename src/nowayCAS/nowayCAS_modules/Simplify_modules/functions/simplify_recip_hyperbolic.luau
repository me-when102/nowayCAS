local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- sech(0) -> 1
	-- csch(0) -> undefined (do NOT simplify)
	-- coth(0) -> undefined (do NOT simplify)
	--
	-- We only simplify the ones that are safe:
	--   sech(0) = 1
	-- csch(0) and coth(0) have singularities, so we leave them alone.
	----------------------------------------------------------------------
	function(name, x)
		if SimplifyHelpers.isZero(x) then
			if name == "sech" then
				return Node.Num("1")
			end
		end
	end,

	----------------------------------------------------------------------
	-- sech(-x) -> sech(x)
	-- csch(-x) -> -csch(x)
	-- coth(-x) -> -coth(x)
	--
	-- Same pattern as trig reciprocals:
	--   - even: sech
	--   - odd:  csch, coth
	----------------------------------------------------------------------
	function(name, x)
		-- matches: -1 * inner
		if x.kind == "op" and x.op == "*" and SimplifyHelpers.isNegOne(x.left) then
			local inner = x.right

			if name == "sech" then
				return Node.Func("sech", {inner})
			end

			if name == "csch" then
				return Node.Op("*", Node.Num("-1"), Node.Func("csch", {inner}))
			end

			if name == "coth" then
				return Node.Op("*", Node.Num("-1"), Node.Func("coth", {inner}))
			end
		end
	end,
}