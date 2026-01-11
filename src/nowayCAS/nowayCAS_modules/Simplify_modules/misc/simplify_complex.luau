local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- 0 + 0i -> 0
	----------------------------------------------------------------------
	function(real, imag)
		if SimplifyHelpers.isZero(real) and SimplifyHelpers.isZero(imag) then
			return Node.Num("0")
		end
	end,

	----------------------------------------------------------------------
	-- a + 0i -> a
	----------------------------------------------------------------------
	function(real, imag)
		if SimplifyHelpers.isZero(imag) then
			return real
		end
	end,

	----------------------------------------------------------------------
	-- 0 + bi -> b*i
	----------------------------------------------------------------------
	function(real, imag)
		if SimplifyHelpers.isZero(real) then
			return Node.Op("*", imag, Node.Const("i"))
		end
	end,

	----------------------------------------------------------------------
	-- Otherwise keep as complex(real, imag)
	----------------------------------------------------------------------
	function(real, imag)
		return Node.Complex(real, imag)
	end,
}