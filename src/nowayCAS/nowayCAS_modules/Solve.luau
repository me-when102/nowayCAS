local Solve = {}

local Node = require(script.Parent.Node)
local Equation = require(script.Parent.Equation)
local Canon = require(script.Parent.Canon)
local Util = require(script.Parent.Util)

-------------------------------------------------------
-- Solver
--
-- High-level symbolic equation solver.
-- This module orchestrates normalization, classification, and
-- specialized solving routines, returning structured solution nodes.
--
--
-- Solves equations symbolically.
-- Entry point: Solve(expr, var)
--
--
-- Solve(expr, var) -> SolutionSet | Solution | NoSolution | UnknownSolve
--   expr : Node (Eq or any expression)
--   var  : Symbol node
--
-- Behavior:
--   - Normalizes equation to Eq(lhs - rhs, 0)
--   - Classifies equation type (linear, quadratic, polynomial, other)
--   - Dispatches to specialized solvers
--   - Returns structured solution nodes
--
--
-- NormalizeEquation(expr, var) -> Eq(normalized_expr, 0) | error
-- ClassifyEquation(eq, var) -> "linear" | "quadratic" | "polynomial" | "other"
-- SolveLinear(eq, var) -> SolutionSet | Solution | NoSolution
-- SolveQuadratic(eq, var) -> SolutionSet | Solution | NoSolution
-- SolvePolynomial(eq, var) -> SolutionSet | UnknownSolve
-- (future: factorization-based)
-------------------------------------------------------

-- Solve an expression or an equation.
function Solve.solve(expr, var)
	local eq = Solve.normalizeEquation(expr, var)
	if eq.kind ~= "equation" or eq.rel ~= "==" then
		return Solve.unknownSolve(expr, var)
	end

	local class = Solve.classifyEquation(eq, var)

	if class == "linear" then
		return Solve.solveLinear(eq, var)
	elseif class == "quadratic" then
		return Solve.solveQuadratic(eq, var)
	elseif class == "polynomial" then
		return Solve.solvePolynomial(eq, var)
	else
		return Solve.unknownSolve(expr, var)
	end
end

-- Normalizes the equation in order to be solved
function Solve.normalizeEquation(expr, var)
	if expr.kind == "equation" then
		local rel = expr.rel  -- e.g. "==", "<", "<=", ">", ">=", "!="

		if rel == "==" then
			-- Only equalities can be normalized to lhs - rhs = 0
			local diff = Node.Op("-", expr.lhs, expr.rhs)
			return Equation.new(Canon.canonical(diff), Node.Num("0"), "==")
		else
			-- Inequalities are not normalized; solver doesn't support them yet
			return Solve.unknownSolve(expr, var)
		end

	else
		-- Raw expression means expr = 0
		return Equation.new(Canon.canonical(expr), Node.Num("0"), "==")
	end
end

-- Returns degree of polynomial in var, or nil if not a polynomial.
function Solve._degree(expr, var)
	local kind = expr.kind

	if kind == "num" or kind == "rat" then
		return 0
	end

	if kind == "var" then
		if expr.name == var.name then
			return 1
		else
			return 0
		end
	end

	if kind == "op" then
		local op = expr.op
		local a, b = expr.left, expr.right

		if op == "+" then
			local da = Solve._degree(a, var)
			local db = Solve._degree(b, var)
			if not da or not db then return nil end
			return math.max(da, db)

		elseif op == "*" then
			local da = Solve._degree(a, var)
			local db = Solve._degree(b, var)
			if not da or not db then return nil end
			return da + db

		elseif op == "^" then
			-- Only allow var^n where n is a numeric literal
			if a.kind == "var" and a.name == var.name and b.kind == "num" then
				return tonumber(b.value)
			else
				return nil
			end
		end

		return nil
	end

	-- Functions, constants, etc. are not polynomials
	return nil
end

-- Determine what type is the equation
function Solve.classifyEquation(eq, var)
	local expr = eq.lhs

	-- Try to extract polynomial degree
	local degree = Solve._degree(expr, var)
	if not degree then
		return "other"
	end

	if degree == 1 then
		return "linear"
	elseif degree == 2 then
		return "quadratic"
	elseif degree >= 3 then
		return "polynomial"
	else
		return "other"
	end
end

-- Solve a linear equation
function Solve.solveLinear(eq, var)
	local coeffs = Util.collectCoefficients(eq.lhs, var)
	if not coeffs then
		return Solve.unknownSolve(eq, var)
	end

	local a = coeffs[1] or Node.Num("0")
	local b = coeffs[0] or Node.Num("0")

	-- a == 0 and b == 0 -> infinite solutions
	if a.kind == "num" and a.value == "0" and b.kind == "num" and b.value == "0" then
		return Solve.InfiniteSolutions()
	end

	-- a == 0 and b != 0 -> no solution
	if a.kind == "num" and a.value == "0" then
		return Solve.NoSolution
	end

	-- x = -b / a
	local negb = Node.Op("*", Node.Num("-1"), b)
	local sol = Node.Op("/", negb, a)

	return Solve.solution({ [var.name] = Canon.canonical(sol) })
end

-- NO WAY! LET'S USE THE QUADRATIC FORMULA AND-
function Solve.solveQuadratic(eq, var)
	local coeffs = Util.collectCoefficients(eq.lhs, var)
	if not coeffs then
		return Solve.unknownSolve(eq, var)
	end

	local a = coeffs[2] or Node.Num("0")
	local b = coeffs[1] or Node.Num("0")
	local c = coeffs[0] or Node.Num("0")

	-- If a == 0, it's not quadratic -> fallback to linear
	if a.kind == "num" and a.value == "0" then
		return Solve.solveLinear(eq, var)
	end

	-- Build discriminant: b^2 - 4ac
	local b2 = Node.Op("^", b, Node.Num("2"))
	local fourac = Node.Op("*", Node.Num("4"), Node.Op("*", a, c))
	local disc = Node.Op("-", b2, fourac)

	-- sqrt(discriminant)
	local sqrt_disc = Node.Func("sqrt", { disc })

	-- -b
	local negb = Node.Op("*", Node.Num("-1"), b)

	-- denominator: 2a
	local denom = Node.Op("*", Node.Num("2"), a)

	-- Solutions:
	-- (-b + sqrt(disc)) / (2a)
	local sol1 = Node.Op("/",
		Node.Op("+", negb, sqrt_disc),
		denom
	)

	-- (-b - sqrt(disc)) / (2a)
	local sol2 = Node.Op("/",
		Node.Op("-", negb, sqrt_disc),
		denom
	)

	-- Canonicalize both
	sol1 = Canon.canonical(sol1)
	sol2 = Canon.canonical(sol2)

	return Solve.solutionSet({
		Solve.solution({ [var.name] = sol1 }),
		Solve.solution({ [var.name] = sol2 })
	})
end

-- AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
function Solve.solvePolynomial(eq, var) end

-------------------------------------------------------
-- Solve Node Constructors
-- Node constructors for solutions
-- Solution({ x = expr }, conditions)
-- SolutionSet({ Solution, Solution, ... })
-- NoSolution
-- InfiniteSolutions
-- UnknownSolve(expr, var)
-------------------------------------------------------

function Solve.solution(bindings, conditions) 
	return {
		kind = "solution",
		bindings = bindings,
		conditions = conditions
	}
end

function Solve.solutionSet(list) 
	return {
		kind = "solutionset",
		list = list
	}
end

Solve.NoSolution = { kind = "nosolution" }
Solve.InfiniteSolutions = { kind = "infinitesolutions" }

function Solve.unknownSolve(expr, var) 
	return {
		kind = "unknownsolve",
		expr = expr,
		var = var
	}
end

return Solve