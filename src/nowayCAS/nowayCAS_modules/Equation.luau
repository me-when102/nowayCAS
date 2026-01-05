local Equation = {}
Equation.__index = Equation

local Canon = require(script.Parent.Canon)
local Arithmetic = require(script.Parent.Arithmetic)
local Print = require(script.Parent.Print)

-------------------------------------------------------
-- Equations
-- Equations are not node kinds and not booleans.
-------------------------------------------------------

-- Creates a new equation with the left expression, right expression, and relation.
function Equation.new(lhs, rhs, rel)
	lhs = Canon.canonical(lhs)
	rhs = Canon.canonical(rhs)

	return setmetatable({
		kind = "Equation",
		lhs = lhs,
		rhs = rhs,
		rel = rel or "==",
	}, Equation)
end

-- Creates a new equal equation with two expressions.
function Equation.eq(lhs, rhs) return Equation.new(lhs, rhs, "==") end

-- Creates a new not-equal equation with two expressions.
function Equation.neq(lhs, rhs) return Equation.new(lhs, rhs, "!=") end

-- Creates a new less-than equation with two expressions.
function Equation.lt(lhs, rhs) return Equation.new(lhs, rhs, "<")  end

-- Creates a new less-than-or-equal-to equation with two expressions.
function Equation.le(lhs, rhs) return Equation.new(lhs, rhs, "<=") end

-- Creates a new greater-than equation with two expressions.
function Equation.gt(lhs, rhs) return Equation.new(lhs, rhs, ">")  end

-- Creates a new greater-than-or-equal-to equation with two expressions.
function Equation.ge(lhs, rhs) return Equation.new(lhs, rhs, ">=") end

-- Applies a function to both sides.
function Equation:map(f)
	return Equation.new(f(self.lhs), f(self.rhs), self.rel)
end

local apply_op_dispatch = {
	add = Arithmetic.add,
	sub = Arithmetic.sub,
	mul = Arithmetic.mul,
	div = Arithmetic.div,
	pow = Arithmetic.pow,
}

-- Apply an arithmetic operation to both sides, symmetric in arguments.
function Equation.apply_op(a, op, b)
	-- If 'a' is not an equation, but 'b' is, swap them.
	if getmetatable(a) ~= Equation then
		-- Now 'b' is the equation, and 'a' is the expr.
		return Equation.apply_op(b, op, a)
	end

	-- At this point, 'a' is guaranteed to be an equation.
	local eq = a
	local expr = b

	local f = apply_op_dispatch[op]
	if not f then
		error("Unknown arithmetic op: " .. tostring(op))
	end

	return Equation.new(
		f(eq.lhs, expr),
		f(eq.rhs, expr),
		eq.rel
	)
end

-- Swap the relation when they are swapped.
local function flip_rel(rel)
	if rel == "<"  then return ">" end
	if rel == ">"  then return "<" end
	if rel == "<=" then return ">=" end
	if rel == ">=" then return "<=" end
	return rel -- == and !=
end

-- Swap the two expressions to opposite sides.
function Equation:swap()
	return Equation.new(self.rhs, self.lhs, flip_rel(self.rel))
end

-- Converts the equation into a readable string.
function Equation:toString()
	return Print._toString(self.lhs) .. " " .. self.rel .. " " .. Print._toString(self.rhs)
end

return Equation