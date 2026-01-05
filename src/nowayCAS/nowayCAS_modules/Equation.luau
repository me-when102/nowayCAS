local Equation = {}
Equation.__index = Equation

local Simplify = require(script.Parent.Simplify)
local Arithmetic = require(script.Parent.Arithmetic)
local Print = require(script.Parent.Print)

-------------------------------------------------------
-- Equations
-- Equations are not node kinds and not booleans.
-------------------------------------------------------

-- Creates a new equation with the left expression, right expression, and relation.
function Equation.new(lhs, rhs, rel)
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
	-- both sides are equations, combine lhs and rhs pairwise.
	if getmetatable(a) == Equation and getmetatable(b) == Equation then
		local f = apply_op_dispatch[op]
		if not f then
			error("Unknown arithmetic op: " .. tostring(op))
		end

		return Equation.new(
			f(a.lhs, b.lhs),
			f(a.rhs, b.rhs),
			a.rel -- keep the relation of the left equation
		)
	end

	-- only one is an equation, swap if needed.
	if getmetatable(a) ~= Equation then
		return Equation.apply_op(b, op, a)
	end

	-- a is equation, b is expr, apply op to both sides.
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

-- Returns the equation in simplified form.
function Equation:simplify()
	return Equation.new(
		Simplify.simplifyDeep(self.lhs),
		Simplify.simplifyDeep(self.rhs),
		self.rel
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

-- Swap two expressions to opposite sides.
function Equation:swap()
	return Equation.new(self.rhs, self.lhs, flip_rel(self.rel))
end

-- Returns the equation with both expressions negated.
function Equation:negate()
	return Equation.new(
		Arithmetic.neg(self.lhs),
		Arithmetic.neg(self.rhs),
		self.rel
	)
end

-- Converts the equation into a readable string.
function Equation:toString()
	return Print._toString(self.lhs) .. " " .. self.rel .. " " .. Print._toString(self.rhs)
end

return Equation