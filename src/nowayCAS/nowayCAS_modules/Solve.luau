local Solve = {}

local Node = require(script.Parent.Node)
local Equation = require(script.Parent.Equation)
local Canon = require(script.Parent.Canon)
local Simplify = require(script.Parent.Simplify)
local Substitute = require(script.Parent.Substitute)
local Util = require(script.Parent.Util)
local Print = require(script.Parent.Print)

-------------------------------------------------------
-- Solver
--
-- Solve Invariants
--
-- - Solvers never mutate input equations.
-- - Solvers always operate on canonicalized expressions.
-- - Solvers never simplify the input equation, only output expressions.
-- - Solving always returns:
--     * Solution
--     * SolutionSet
--     * NoSolution
--     * InfiniteSolutions
--     * UnknownSolve
-- - Equations are separate objects (not expressions).
-- - Equation.lhs and Equation.rhs are always AST nodes.
-------------------------------------------------------

-------------------------------------------------------
-- Kinds / Tags
-------------------------------------------------------

Solve.kind = {
	SOLUTION = "solution",
	SET = "solutionset",
	NONE = "nosolution",
	INFINITE = "infinitesolutions",
	UNKNOWN = "unknownsolve",
}

-------------------------------------------------------
-- Context
-- (Domain, numeric fallback, etc. can grow here.)
-------------------------------------------------------

local defaultContext = {
	domain = "real",          -- "real" | "complex" | etc.
	allowComplex = false,     -- whether complex roots are allowed
	numericFallback = false,  -- future: numeric solvers
	maxDegree = 4,            -- future: polynomial degree limits
}

local function mergeContext(ctx)
	if not ctx then
		return defaultContext
	end

	-- shallow merge is enough for now
	local out = {}
	for k, v in pairs(defaultContext) do
		out[k] = v
	end
	for k, v in pairs(ctx) do
		out[k] = v
	end
	return out
end

-------------------------------------------------------
-- Classifier and Solver Registries
-------------------------------------------------------

Solve.classifiers = {}  -- name -> fn(eq, var, ctx) -> class or nil
Solve.solvers = {}      -- class -> fn(eq, var, ctx) -> SolveResult

-- Classifies the polynomial by its degree.
local function classifyPolynomial(eq, var, ctx)
	local degree = Solve._degree(eq.lhs, var)
	if not degree then
		return nil
	end

	if degree == 1 then
		return "linear"
	elseif degree == 2 then
		return "quadratic"
	elseif degree >= 3 then
		return "polynomial"
	end

	return nil
end

Solve.classifiers.polynomial = classifyPolynomial

-------------------------------------------------------
-- Pipeline Hooks
-- pre:  eq, var, ctx -> eq'
-- post: result, eq, var, ctx -> result'
-------------------------------------------------------

Solve.pipeline = {
	pre = {},
	post = {},
}

-------------------------------------------------------
-- Degree helper
-------------------------------------------------------

-- Determines the degree of the polynomial based on the current structure.
function Solve._degree(expr, var)
	if Util.isNum(expr) or Util.isRat(expr) then
		return 0
	end

	if Util.isVar(expr) then
		if expr.name == var.name then
			return 1
		else
			return 0
		end
	end

	if Util.isComplex(expr) then
		return 0
	end

	if Util.isOp(expr) then
		local op = expr.op
		local a, b = expr.left, expr.right

		if op == "+" or op == "-" then
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
			if Util.isVar(a) and a.name == var.name and Util.isNum(b) then
				return tonumber(b.value)
			end

			-- (c * x)^n
			if Util.isOp(a) and a.op == "*" then
				local da = Solve._degree(a, var)
				if da == 1 and Util.isNum(b) then
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

-------------------------------------------------------
-- Normalization
-- - Equations are normalized to lhs - rhs == 0 for equalities.
-- - Inequalities are currently unsupported -> UnknownSolve.
-- - Piecewise equations are passed through unchanged.
-- - Canonicalization is applied here; no simplification.
-------------------------------------------------------

-- Normalizes the expression (lhs or rhs) for equalities.
-- Piecewise functions are not normalized.
function Solve.normalizeEquation(expr, var)
	if expr.kind == "equation" then
		local rel = expr.rel

		-- do not normalize piecewise equations
		if Util.isPiecewise(expr.lhs) or Util.isPiecewise(expr.rhs) then
			return expr
		end

		if rel == "==" then
			local diff = Node.Op("-", expr.lhs, expr.rhs)
			return Equation.new(Canon.canonical(diff), Node.Num("0"), "==")
		else
			-- inequalities unsupported for now
			return nil, "unsupported_relation"
		end
	else
		-- raw expression means expr = 0
		return Equation.new(Canon.canonical(expr), Node.Num("0"), "==")
	end
end

-------------------------------------------------------
-- Classification
-- Runs all registered classifiers until one returns a class.
-------------------------------------------------------

-- Determines the equation's class.
function Solve.classifyEquation(eq, var, ctx)
	for name, fn in pairs(Solve.classifiers) do
		local class = fn(eq, var, ctx)
		if class ~= nil then
			return class
		end
	end
	return nil
end

-------------------------------------------------------
-- Core Solve Entry Point
-------------------------------------------------------

-- Returns a solution set for solving an expression or an equation for a varaible.
function Solve.solve(expr, var, ctx)
	ctx = mergeContext(ctx)

	-- Normalize equation (canonical only, no simplify).
	local eq, err = Solve.normalizeEquation(expr, var)
	if not eq then
		return Solve.unknownSolve(expr, var, { reason = err })
	end

	if eq.kind ~= "equation" or eq.rel ~= "==" then
		return Solve.unknownSolve(expr, var, { reason = "non_equality" })
	end

	-- Piecewise solving hook (future: dedicated classifier/solver).
	if Util.isPiecewise(eq.lhs) or Util.isPiecewise(eq.rhs) then
		local solver = Solve.solvers["piecewise"]
		if solver then
			return solver(eq, var, ctx)
		else
			return Solve.unknownSolve(eq, var, { reason = "piecewise_unsupported" })
		end
	end

	-- Pre-pipeline transforms (do not simplify, do not mutate).
	for _, fn in ipairs(Solve.pipeline.pre) do
		eq = fn(eq, var, ctx) or eq
	end

	-- Classify equation.
	local class = Solve.classifyEquation(eq, var, ctx)
	if not class then
		return Solve.unknownSolve(expr, var, { reason = "unclassified" })
	end

	-- Dispatch to solver.
	local solver = Solve.solvers[class]
	if not solver then
		return Solve.unknownSolve(expr, var, { reason = "no_solver_for_class", class = class })
	end

	local result = solver(eq, var, ctx)

	-- Post-pipeline transforms (e.g., verify roots, filter by domain).
	for _, fn in ipairs(Solve.pipeline.post) do
		result = fn(result, eq, var, ctx) or result
	end

	return result
end

-------------------------------------------------------
-- Built-in Solvers (linear, quadratic, polynomial, piecewise)
-------------------------------------------------------

-- Solves a linear equation.
local function solveLinear(eq, var, ctx)
	local coeffs = Util.collectCoefficients(eq.lhs, var)
	if not coeffs then
		return Solve.unknownSolve(eq, var, { reason = "collect_failed" })
	end

	local a = coeffs[1] or Node.Num("0")
	local b = coeffs[0] or Node.Num("0")

	-- a == 0 and b == 0 -> infinite solutions
	if Util.isZero(a) and Util.isZero(b) then
		return Solve.InfiniteSolutions
	end

	-- a == 0 and b != 0 -> no solution
	if Util.isZero(a) then
		return Solve.NoSolution
	end

	-- x = -b / a
	local negb = Node.Op("*", Node.Num("-1"), b)
	local sol = Node.Op("/", negb, a)

	-- Simplify output only.
	sol = Simplify.simplifyDeep(sol)

	return Solve.solution({ [var.name] = sol })
end

-- Solves a quadratic equation.
local function solveQuadratic(eq, var, ctx)
	local coeffs = Util.collectCoefficients(eq.lhs, var)
	if not coeffs then
		return Solve.unknownSolve(eq, var, { reason = "collect_failed" })
	end

	local a = coeffs[2] or Node.Num("0")
	local b = coeffs[1] or Node.Num("0")
	local c = coeffs[0] or Node.Num("0")

	-- If a == 0, fallback to linear.
	if Util.isZero(a) then
		return solveLinear(eq, var, ctx)
	end

	-- discriminant: b^2 - 4ac
	local b2 = Node.Op("^", b, Node.Num("2"))
	local fourac = Node.Op("*", Node.Num("4"), Node.Op("*", a, c))
	local disc = Node.Op("-", b2, fourac)

	local sqrt_disc = Node.Func("sqrt", { disc })
	local negb = Node.Op("*", Node.Num("-1"), b)
	local denom = Node.Op("*", Node.Num("2"), a)

	local sol1 = Node.Op("/",
		Node.Op("+", negb, sqrt_disc),
		denom
	)

	local sol2 = Node.Op("/",
		Node.Op("-", negb, sqrt_disc),
		denom
	)

	sol1 = Simplify.simplifyDeep(sol1)
	sol2 = Simplify.simplifyDeep(sol2)

	return Solve.solutionSet({
		Solve.solution({ [var.name] = sol1 }),
		Solve.solution({ [var.name] = sol2 }),
	})
end

-- Solves a polynomial of any degree.
local function solvePolynomial(eq, var, ctx)
	-- TODO: factorization-based, numeric, etc.
	return Solve.unknownSolve(eq, var, { reason = "polynomial_unimplemented" })
end

-- Solves a piecewise equation.
local function solvePiecewise(eq, var, ctx)
	local anyUnknown = false
	local anySolved = false

	-- Identify the piecwise side.
	local lhs, rhs = eq.lhs, eq.rhs
	local pw, other, pwOnLHS

	if Util.isPiecewise(lhs) then
		pw = lhs
		other = rhs
		pwOnLHS = true
	else
		pw = rhs
		other = lhs
		pwOnLHS = false
	end

	local solutions = {}

	-- Solve each branch independently.
	for _, branch in ipairs(pw.branches) do
		local cond = branch[1]
		local expr = branch[2]

		-- build sub-equation: expr == other
		local subEq
		if pwOnLHS then
			subEq = Equation.new(
				Canon.canonical(Node.Op("-", expr, other)),
				Node.Num("0"),
				"=="
			)
		else
			subEq = Equation.new(
				Canon.canonical(Node.Op("-", other, expr)),
				Node.Num("0"),
				"=="
			)
		end

		-- Solve the branch.
		local subResult = Solve.solve(subEq, var, ctx)

		-- Handle each result type.
		if subResult.kind == Solve.kind.SOLUTION then
			anySolved = true
			-- Attach branch condition.
			table.insert(solutions, Solve.solution(
				subResult.bindings,
				{ cond },
				subResult.meta
				))

		elseif subResult.kind == Solve.kind.SET then
			anySolved = true
			-- Attach condition to each solution
			for _, sol in pairs(subResult.list) do
				table.insert(solutions, Solve.solution(
					sol.bindings,
					{ cond },
					sol.meta
					))
			end

		elseif subResult.kind == Solve.kind.INFINITE then
			-- Solution is infinite, do nothing.
			anySolved = true
		elseif subResult.kind == Solve.kind.UNKNOWN then
			-- Solution is unknown, do nothing.
			anyUnknown = true
		end
	end

	-- No branches produced usable solutions.
	if #solutions == 0 then
		if anyUnknown then
			return Solve.unknownSolve(eq, var, { reason = "piecewise_all_unknown" })
		else
			return Solve.NoSolution
		end
	end

	-- Filter solutions by feasibility.
	local filtered = {}
	for _, sol in ipairs(solutions) do
		if sol.kind == Solve.kind.SOLUTION then
			local cond = sol.conditions[1]

			-- Substitute variable into condition.
			local substituted = Substitute.apply(cond, sol.bindings)

			-- Evaluate condition.
			local eval = Simplify.simplifyDeep(substituted)

			if Util.isTrue(eval) then
				table.insert(filtered, sol)
			end

		else
			-- Infinite or unknown: keep as-is.
			table.insert(filtered, sol)
		end
	end

	if #filtered == 0 then return Solve.NoSolution end

	-- If all are infinite solutions, collapse.
	local allInfinite = true
	for _, sol in ipairs(filtered) do
		if sol.kind ~= Solve.kind.INFINITE then
			allInfinite = false
			break
		end
	end
	if allInfinite then return Solve.InfiniteSolutions end

	-- If exactly one solution, return it.
	if #filtered == 1 and filtered[1].kind == Solve.kind.SOLUTION then
		return Solve.solutionSet({ filtered[1] })
	end

	-- Otherwise, return a solution set.
	return Solve.solutionSet(filtered)
end

Solve.solvers.linear = solveLinear
Solve.solvers.quadratic = solveQuadratic
Solve.solvers.polynomial = solvePolynomial
Solve.solvers.piecewise = solvePiecewise

-------------------------------------------------------
-- Solution Metatable
-------------------------------------------------------

local SolutionMT = {}

-- Field/method lookup: sol.x or sol:get("x")
SolutionMT.__index = function(t, key)
	if t.bindings and t.bindings[key] then
		return t.bindings[key]
	end
	return rawget(SolutionMT, key)
end

-- Returns the expression bound to a variable name.
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
	if type(key) == "number" then
		return t.list[key]
	end
	return rawget(SolutionSetMT, key)
end

-- Returns the first solution in the set.
function SolutionSetMT:first()
	return self.list[1]
end

-- Returns a solution by index, or all values of a variable across solutions.
function SolutionSetMT:get(var)
	if type(var) == "number" then
		return self.list[var]
	end

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
-- Non-Solution Metatable
-------------------------------------------------------

local NonSolutionMT = {}

-- Returns the non-solution set converted into a string.
function NonSolutionMT:__tostring()
	if self.kind == Solve.kind.NONE then
		return "NoSolution"
	elseif self.kind == Solve.kind.INFINITE then
		return "InfiniteSolutions"
	elseif self.kind == Solve.kind.UNKNOWN then
		local reason = (self.meta and self.meta.reason) or "?"
		return "UnknownSolve(" .. reason .. ")"
	end
	return "<invalid non-solution>"
end

-- Returns the non-solution set converted into a string.
function NonSolutionMT:toString()
	return self:__tostring()
end

-- Returns the non-solution set converted into LaTeX form.
function NonSolutionMT:toLatex()
	if self.kind == Solve.kind.NONE then
		return "\\text{No Solution}"
	elseif self.kind == Solve.kind.INFINITE then
		return "\\text{Infinite Solutions}"
	elseif self.kind == Solve.kind.UNKNOWN then
		local reason = (self.meta and self.meta.reason) or "?"
		return "\\text{Unknown Solve: " .. reason .. "}"
	end
	return "\\text{Invalid Non-Solution}"
end

-------------------------------------------------------
-- Constructors
-------------------------------------------------------

-- Constructs a solution with bindings, conditions, and a meta.
function Solve.solution(bindings, conditions, meta)
	return setmetatable({
		kind = Solve.kind.SOLUTION,
		bindings = bindings,
		conditions = conditions,
		meta = meta or {},
	}, SolutionMT)
end

-- Constructs a solution set with a list of solutions and a meta.
function Solve.solutionSet(list, meta)
	return setmetatable({
		kind = Solve.kind.SET,
		list = list,
		meta = meta or {},
	}, SolutionSetMT)
end

Solve.NoSolution = setmetatable({
	kind = Solve.kind.NONE
}, NonSolutionMT)

Solve.InfiniteSolutions = setmetatable({
	kind = Solve.kind.INFINITE
}, NonSolutionMT)

-- Constructs an unknown solve set of the expression, the varaible, and a meta.
function Solve.unknownSolve(expr, var, meta)
	return setmetatable({
		kind = Solve.kind.UNKNOWN,
		expr = expr,
		var = var,
		meta = meta or {},
	}, NonSolutionMT)
end

-- The Solver sub-library.
return Solve