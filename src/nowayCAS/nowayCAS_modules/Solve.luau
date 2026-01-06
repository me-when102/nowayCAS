local Solve = {}

local Node = require(script.Parent.Node)
local Equation = require(script.Parent.Equation)
local Canon = require(script.Parent.Canon)

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

-- solve something right now
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

function Solve.classifyEquation(eq, var)
	-- TODO: polynomial extractor
	return "other"
end


-- easy
function Solve.solveLinear(eq, var) end

-- NO WAY! LET'S USE THE QUADRATIC FORMULA AND-
function Solve.solveQuadratic(eq, var) end

-- AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
function Solve.solvePolynomial(eq, var) end

-------------------------------------------------------
-- Solve Node Constructors
-- Node constructors for solutions
-- Solution({ x = expr }, conditions)
-- SolutionSet({ Solution, Solution, ... })
-- NoSolution
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

function Solve.unknownSolve(expr, var) 
	return {
		kind = "unknownsolve",
		expr = expr,
		var = var
	}
end

return Solve