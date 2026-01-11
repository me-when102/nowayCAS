local Node = require(script.Parent.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Parent.Util)
local Assume = require(script.Parent.Parent.Parent.Assume)

return {

	----------------------------------------------------------------------
	-- x == x, x <= x, x >= x  -> true
	-- x < x, x > x, x != x    -> false
	----------------------------------------------------------------------
	function(a, b, op)
		if not (op == "<" or op == "<=" or op == ">" or op == ">=" or op == "==" or op == "!=") then
			return
		end

		if Util.nodeEquals(a, b) then
			if op == "==" or op == "<=" or op == ">=" then
				return Node.Const("true")
			else
				return Node.Const("false")
			end
		end
	end,

	----------------------------------------------------------------------
	-- Assumption‑based simplification
	-- Only applies when comparing a variable to a numeric literal.
	----------------------------------------------------------------------
	function(a, b, op)
		if not (op == "<" or op == "<=" or op == ">" or op == ">=" or op == "==" or op == "!=") then
			return
		end

		if a.kind == "var" and b.kind == "num" then
			local x = a.name
			local n = tonumber(b.value)

			if n == 0 then

				-- x > 0 or x >= 0
				if Assume.is(x, "positive") then
					if op == ">" or op == ">=" then return Node.Const("true") end
					if op == "<" or op == "<=" then return Node.Const("false") end
				end

				-- x < 0 or x <= 0
				if Assume.is(x, "negative") then
					if op == "<" or op == "<=" then return Node.Const("true") end
					if op == ">" or op == ">=" then return Node.Const("false") end
				end

				-- x == 0
				if Assume.is(x, "zero") then
					if op == "==" then return Node.Const("true") end
					if op == "!=" then return Node.Const("false") end
				end

				-- x != 0
				if Assume.is(x, "nonzero") then
					if op == "==" then return Node.Const("false") end
					if op == "!=" then return Node.Const("true") end
				end
			end
		end
	end,
}