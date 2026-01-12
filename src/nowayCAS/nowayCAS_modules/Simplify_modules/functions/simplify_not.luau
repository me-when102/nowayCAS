local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- Boolean NOT
	-- not true -> false
	-- not false -> true
	----------------------------------------------------------------------
	function(name, arg)
		if Util.isTrue(arg) then
			return Node.Const("false")
		end

		if Util.isFalse(arg) then
			return Node.Const("true")
		end
	end,
}