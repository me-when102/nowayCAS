local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- x - 0 -> x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isZero(b) then
			return a
		end
	end,

	----------------------------------------------------------------------
	-- 0 - x -> (-1) * x
	----------------------------------------------------------------------
	function(a, b)
		if Util.isZero(a) then
			return Node.Op("*", Node.Num("-1"), b)
		end
	end,
}