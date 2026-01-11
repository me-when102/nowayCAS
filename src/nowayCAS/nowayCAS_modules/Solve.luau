local Solve = {}

local Node = require(script.Parent.Node)
local Equation = require(script.Parent.Equation)
local Canon = require(script.Parent.Canon)
local Simplify = require(script.Parent.Simplify)
local Util = require(script.Parent.Util)
local Print = require(script.Parent.Print)

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

-- Solve an expression or an equation for a variable.
function Solve.solve(expr, var)
	local eq = Solve.normalizeEquation(expr, var)

	if eq.kind ~= "equation" or eq.rel ~= "==" then
		return Solve.unknownSolve(expr, var)
	end

	-- piecewise solving
	if eq.lhs.kind == "piecewise" or eq.rhs.kind == "piecewise" then
		return Solve.solvePiecewise(eq, var)
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

-- Normalizes the equation in order to be solved.
function Solve.normalizeEquation(expr, var)
	if expr.kind == "equation" then
		local rel = expr.rel  -- e.g. "==", "<", "<=", ">", ">=", "!="
		
		-- do not normalize piecewise equations
		if expr.lhs.kind == "piecewise" or expr.rhs.kind == "piecewise" then
			return expr
		end

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

	if kind == "complex" then
		return 0
	end

	if kind == "op" then
		local op = expr.op
		local a, b = expr.left, expr.right

		if op == "+" then
			local da = Solve._degree(a, var)
			local db = Solve._degree(b, var)
			if not da or not db then return nil end
			return math.max(da, db)

		elseif op == "-" then
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
			-- x^n
			if a.kind == "var" and a.name == var.name and b.kind == "num" then
				return tonumber(b.value)
			end

			-- (-1 * x)^n  or  (c * x)^n
			if a.kind == "op" and a.op == "*" then
				-- Look for x inside the product
				local da = Solve._degree(a, var)
				if da == 1 and b.kind == "num" then
					return tonumber(b.value)
				end
			end

			return nil
		end

		return nil
	end

	-- Functions, constants, etc. are not polynomials
	return nil
end

-- Determine what type is the equation.
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

-- Solve a linear equation.
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

-- Solve a quadratic equation.
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

	-- Simplify both
	sol1 = Simplify.simplifyDeep(sol1)
	sol2 = Simplify.simplifyDeep(sol2)

	return Solve.solutionSet({
		Solve.solution({ [var.name] = sol1 }),
		Solve.solution({ [var.name] = sol2 })
	})
end

-- TODO: implement full polynomial solving
-- Solve a general polynomial equation.
function Solve.solvePolynomial(eq, var) 
	return Solve.unknownSolve(eq, var)
end

-- TODO: implement piecewise solving
-- Solve a piecewise function.
function Solve.solvePiecewise(eq, var)
    return Solve.unknownSolve(eq, var)
end

-------------------------------------------------------
-- Solve Node Constructors and External API
-- Node constructors for solutions
-- Solution({ x = expr }, conditions)
-- SolutionSet({ Solution, Solution, ... })
-- NoSolution
-- InfiniteSolutions
-- UnknownSolve(expr, var)
-------------------------------------------------------

-------------------------------------------------------
-- Solution Metatable
-- Represents a single solution.
-------------------------------------------------------

local SolutionMT = {}

-- Field/method lookup: sol.x or sol:get("x")
SolutionMT.__index = function(t, key)
	-- direct access: sol.x
	if t.bindings and t.bindings[key] then
		return t.bindings[key]
	end

	-- method access: sol:get("x")
	return rawget(SolutionMT, key)
end

-- Returns the expression bound to a varaible name.
function SolutionMT:get(var)
	return self.bindings[var]
end

-- Returns a list of all variable names in this solution.
function SolutionMT:variables()
	local vars = {}
	for k in pairs(self.bindings) do
		vars[#vars+1] = k
	end
	return vars
end

-- Returns the solution as a string formatted as "(x = ..., y = ...)".
function SolutionMT:__tostring()
	local parts = {}
	for var, expr in pairs(self.bindings) do
		table.insert(parts, var .. " = " .. Print._toString(expr))
	end
	return "(" .. table.concat(parts, ", ") .. ")"
end

-- Returns the solution as a string formatted as "(x = ..., y = ...)".
function SolutionMT:toString()
	local parts = {}
	for var, expr in pairs(self.bindings) do
		table.insert(parts, var .. " = " .. Print._toString(expr))
	end
	return "(" .. table.concat(parts, ", ") .. ")"
end

-- Returns the solution formatted in LaTeX.
function SolutionMT:toLatex()
	local parts = {}
	for var, expr in pairs(self.bindings) do
		table.insert(parts, var .. " = " .. Print._toLatex(expr))
	end
	return "\\left(" .. table.concat(parts, ",\\; ") .. "\\right)"
end

-------------------------------------------------------
-- Solution Set Metatable
-------------------------------------------------------

local SolutionSetMT = {}

-- Field/method lookup + numeric indexing: solset[1]
SolutionSetMT.__index = function(t, key)
	-- allow numeric indexing: solset[1]
	if type(key) == "number" then
		return t.list[key]
	end

	-- method access
	return rawget(SolutionSetMT, key)
end

-- Returns the first solution in the set.
function SolutionSetMT:first()
	return self.list[1]
end

-- Returns a solution by index, or all values of a variable across solutions.
function SolutionSetMT:get(var)
	-- numeric index -> return that solution
	if type(var) == "number" then
		return self.list[var]
	end

	-- variable name -> return all values for that variable
	local out = {}
	for i, sol in ipairs(self.list) do
		out[i] = sol[var]
	end
	return out
end

-- Returns the raw list of solutions.
function SolutionSetMT:all()
	return self.list
end

-- Returns the solution set converted into a string.
function SolutionSetMT:__tostring()
	local out = {}
	for i, sol in ipairs(self.list) do
		out[#out+1] = tostring(sol)
	end
	return "{ " .. table.concat(out, ", ") .. " }"
end

-- Returns the solution set converted into a string.
function SolutionSetMT:toString()
	local out = {}
	for i, sol in ipairs(self.list) do
		out[#out+1] = tostring(sol)
	end
	return "{ " .. table.concat(out, ", ") .. " }"
end

-- Returns the solution set formatted in LaTeX.
function SolutionSetMT:toLatex()
	local out = {}
	for i, sol in ipairs(self.list) do
		out[#out+1] = sol:toLatex()
	end
	return "{ " .. table.concat(out, ", ") .. " }"
end

-------------------------------------------------------
-- Actual Constructors
-------------------------------------------------------

-- Constructs a solution.
function Solve.solution(bindings, conditions)
	return setmetatable({
		kind = "solution",
		bindings = bindings,
		conditions = conditions
	}, SolutionMT)
end

-- Constructs a solution set.
function Solve.solutionSet(list)
	return setmetatable({
		kind = "solutionset",
		list = list
	}, SolutionSetMT)
end

-- No solution table.
Solve.NoSolution = { kind = "nosolution" }

-- Infinite solutions table.
Solve.InfiniteSolutions = { kind = "infinitesolutions" }

-- Constructs an unknown solve.
function Solve.unknownSolve(expr, var) 
	return {
		kind = "unknownsolve",
		expr = expr,
		var = var
	}
end

-- The Solve sub-library.
return Solve