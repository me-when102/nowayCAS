local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- x - 0 -> x
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isZero(b) then
			return a
		end
	end,

	----------------------------------------------------------------------
	-- 0 - x -> (-1) * x
	----------------------------------------------------------------------
	function(a, b)
		if SimplifyHelpers.isZero(a) then
			return Node.Op("*", Node.Num("-1"), b)
		end
	end,
}