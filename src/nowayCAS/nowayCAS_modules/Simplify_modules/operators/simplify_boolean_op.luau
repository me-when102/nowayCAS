local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- Boolean AND
	-- true and x -> x
	-- false and x -> false
	-- x and true -> x
	-- x and false -> false
	----------------------------------------------------------------------
	function(a, b, op)
		if op ~= "and" then return end

		if Util.isTrue(a) then
			return b
		end

		if Util.isFalse(a) then
			return Node.Const("false")
		end

		if Util.isTrue(b) then
			return a
		end

		if Util.isFalse(b) then
			return Node.Const("false")
		end
	end,

	----------------------------------------------------------------------
	-- Boolean OR
	-- true or x -> true
	-- false or x -> x
	-- x or true -> true
	-- x or false -> x
	----------------------------------------------------------------------
	function(a, b, op)
		if op ~= "or" then return end

		if Util.isTrue(a) then
			return Node.Const("true")
		end

		if Util.isFalse(a) then
			return b
		end

		if Util.isTrue(b) then
			return Node.Const("true")
		end

		if Util.isFalse(b) then
			return a
		end
	end,

}