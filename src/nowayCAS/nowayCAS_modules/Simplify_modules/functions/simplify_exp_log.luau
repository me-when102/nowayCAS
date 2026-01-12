local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)

return {

	----------------------------------------------------------------------
	-- exp(0) = 1
	----------------------------------------------------------------------
	function(name, x)
		if name == "exp" and Util.isZero(x) then
			return Node.Num("1")
		end
	end,

	----------------------------------------------------------------------
	-- ln(1) = 0
	----------------------------------------------------------------------
	function(name, x)
		if name == "ln" and Util.isOne(x) then
			return Node.Num("0")
		end
	end,

	----------------------------------------------------------------------
	-- log10(1) = 0
	----------------------------------------------------------------------
	function(name, x)
		if name == "log10" and Util.isOne(x) then
			return Node.Num("0")
		end
	end,

	----------------------------------------------------------------------
	-- log(x, base)
	-- Only simplify trivial cases:
	--   log(1, b) = 0
	--   log(a, a) = 1
	--   log(a, 1) = undefined → leave symbolic
	----------------------------------------------------------------------
	function(name, x, base)
		if name ~= "log" then return end

		-- log(1, b) = 0
		if Util.isOne(x) then
			return Node.Num("0")
		end

		-- log(a, a) = 1
		if Util.nodeEquals(x, base) then
			return Node.Num("1")
		end

		-- log(a, 1) is undefined -> do nothing
	end,

	----------------------------------------------------------------------
	-- exp(ln(x)) = x
	-- ln(exp(x)) = x
	-- Only when this SHORTENS the expression
	----------------------------------------------------------------------
	function(name, x)
		-- exp(ln(x)) → x
		if name == "exp"
			and x.kind == "func"
			and x.name == "ln" then
			return x.args[1]
		end

		-- ln(exp(x)) → x
		if name == "ln"
			and x.kind == "func"
			and x.name == "exp" then
			return x.args[1]
		end
	end,
}