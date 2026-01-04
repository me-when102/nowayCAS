local rules_algebraic = {}

local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)
local Rewrite = require(script.Parent)

local R = Rewrite.R
-------------------------------------------------------
-- Algebraic Simplifications (Factorization, Cancellation,
-- Rational simplification, Structural rewrites)
-------------------------------------------------------

rules_algebraic.simplify = {
	-- (x^2 - y^2) / (x - y) - > x + y
	R("(_u^2 + -(_v^2)) / (_u + -(_v))", "_u + _v"),
}

return rules_algebraic