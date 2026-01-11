local Node = require(script.Parent.Parent.Parent.Node)
local SimplifyHelpers = require(script.Parent.Parent.SimplifyHelpers)

return {

	----------------------------------------------------------------------
	-- Constant folding (only when expression becomes shorter)
	-- asec(1)  = 0
	-- acsc(1)  = pi/2   (longer -> leave symbolic)
	-- acot(1)  = pi/4   (longer -> leave symbolic)
	--
	-- asec(-1) = pi     (longer -> leave symbolic)
	-- acsc(-1) = -pi/2  (longer -> leave symbolic)
	-- acot(-1) = -pi/4  (longer -> leave symbolic)
	----------------------------------------------------------------------
	function(name, x)
		-- asec(1) = 0 is the only one that strictly shortens
		if name == "asec" and SimplifyHelpers.isOne(x) then
			return Node.Num("0")
		end

		-- Everything else stays symbolic
	end,

	----------------------------------------------------------------------
	-- Odd/even symmetry
	-- asec(-x) = pi - asec(x)   (unsafe -> do NOT simplify)
	-- acsc(-x) = -acsc(x)       (safe)
	-- acot(-x) = -acot(x)       (safe)
	----------------------------------------------------------------------
	function(name, x)
		if x.kind == "op" and x.op == "*" and SimplifyHelpers.isNegOne(x.left) then
			local inner = x.right

			-- acsc(-x) = -acsc(x)
			if name == "acsc" then
				return Node.Op("*", Node.Num("-1"), Node.Func("acsc", {inner}))
			end

			-- acot(-x) = -acot(x)
			if name == "acot" then
				return Node.Op("*", Node.Num("-1"), Node.Func("acot", {inner}))
			end

			-- asec(-x) identity involves pi and is unsafe -> skip
		end
	end,
}