local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- Boolean NOT
	-- not true -> false
	-- not false -> true
	----------------------------------------------------------------------
	function(name, arg)
		if SimplifyHelpers.isTrue(arg) then
			return Node.Const("false")
		end

		if SimplifyHelpers.isFalse(arg) then
			return Node.Const("true")
		end
	end,
}