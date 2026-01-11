local rules_algebraic = {}

local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)
local Rewrite = require(script.Parent)
local Assume = require(script.Parent.Parent.Assume)

local R = Rewrite.R
local RF = Rewrite.RF
-------------------------------------------------------
-- Algebraic Simplifications (Factorization, Cancellation,
-- Rational simplification, Structural rewrites)
-------------------------------------------------------

rules_algebraic.simplify = {
	-- (x^2 - y^2) / (x - y) - > x + y
	R("(_u^2 + -(_v^2)) / (_u + -(_v))", "_u + _v"),
	
	-- ln(x * y) = ln(x) + ln(y) if x and y > 0
	RF("ln(_x * _y)", function(node, env)
		local x = env._x
		local y = env._y

		if Assume.is(x, "positive") and Assume.is(y, "positive") then
			return Node.Op("+",
				Node.Func("ln", { x }),
				Node.Func("ln", { y })
			)
		end

		return node
	end),
	
	-- (u * x + v) / x -> u + v/x
	R("(_u * _x + _v) / _x", "_u + _v / _x"),
	
	-- (u * x - v) / x -> u - v/x
	R("(_u * _x + -(_v)) / _x", "_u - _v / _x"),
	
	-- (u * x) / x -> u   (assumes x ~= 0; unguarded)
	RF("(_u * _x) / _x", function(node, env)
		local x = env._x

		-- numeric nonzero
		if x.kind == "num" and tonumber(x.value) ~= 0 then
			return env._u
		end

		-- rational nonzero
		if x.kind == "rat" and x.num ~= 0 then
			return env._u
		end

		-- variable with assumption
		if x.kind == "var" and Assume.is(x, "nonzero") then
			return env._u
		end

		return node
	end),
	
	-- (a / x) + (b / x) -> (a + b) / x
	R("(_a / _d) + (_b / _d)", "(_a + _b) / _d"),
	
	-- (a / x) - (b / x) -> (a - b) / x
	R("(_a / _d) - (_b / _d)", "(_a - _b) / _d"),
	
	-- sin(x)^2 + cos(x)^2 = 1
	R("sin(_x)^2 + cos(_x)^2", "1"),
	R("cos(_x)^2 + sin(_x)^2", "1"),
}

return rules_algebraic