local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- asech(0)  -> no simplification (undefined)
	-- acsch(0)  -> 0
	-- acoth(0)  -> no simplification (undefined)
	--
	-- Only acsch(0) is safe.
	----------------------------------------------------------------------
	function(name, x)
		if SimplifyHelpers.isZero(x) then
			if name == "acsch" then
				return Node.Num("0")
			end
			-- asech(0) and acoth(0) are undefined → no simplification
		end
	end,

	----------------------------------------------------------------------
	-- asech(-x) -> no simplification (not even/odd)
	-- acsch(-x) -> -acsch(x)
	-- acoth(-x) -> -acoth(x)
	--
	-- Only acsch and acoth are odd.
	----------------------------------------------------------------------
	function(name, x)
		-- matches: -1 * inner
		if x.kind == "op" and x.op == "*" and SimplifyHelpers.isNegOne(x.left) then
			local inner = x.right

			if name == "acsch" then
				return Node.Op("*", Node.Num("-1"), Node.Func("acsch", {inner}))
			end

			if name == "acoth" then
				return Node.Op("*", Node.Num("-1"), Node.Func("acoth", {inner}))
			end

			-- asech(-x) has no symmetry we can use
		end
	end,
}