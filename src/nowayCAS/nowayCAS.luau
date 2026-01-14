--[[
	nowayCAS: a symbolic algebra system module in the nowayCAS library
	
	Invariants:
		------------------------------------------------------------------------
			AST & Node Model Invariants
		------------------------------------------------------------------------
		- All expressions are immutable trees (AST).
		- Node kinds: "num", "var", "op", "func", "const", "rat", "complex", "piecewise".
		- Operators are fixed-arity binary infix constructs represented by literal operator strings.
		- Functions are prefix constructs with explicit argument lists; postfix operators are parsed into function calls.
		- Unary logical negation ("not") is represented as a function, not an operator.
		- First-class objects expose { kind = "..." } with lowercase names.
		- No node stores parent references.
		- Only func.args and piecewise.branches may contain raw Lua tables.
		- No node contains approximate numeric values (floats, scientific notation, rounded integers).

		------------------------------------------------------------------------
			Numeric Representation Invariants
		------------------------------------------------------------------------
		- Number nodes store their numeric value as a string literal, not a Lua number.
		- Rational nodes store normalized integers (gcd = 1, denominator > 0).
		- A node cannot represent multiple numeric types simultaneously.
		- Symbolic tasks must not overflow IEEE-754’s exact integer range.

		------------------------------------------------------------------------
			Piecewise Invariants
		------------------------------------------------------------------------
		- Piecewise nodes store ordered { condition, expression } pairs.
		- Conditions are AST boolean expressions; invalid conditions default to false.
		- A final unconditional branch may be represented as { true, expr }.
		- Piecewise nodes may appear anywhere in an expression.
		- Solvers must propagate conditions.
		- Simplify distributes over piecewise branches.

		------------------------------------------------------------------------
			Canonicalization Invariants
		------------------------------------------------------------------------
		- Canonicalization is defined for all valid ASTs and is idempotent.
		- Canonicalization never calls Simplify.
		- Canonicalization only restructures expressions; it never changes algebraic meaning.
		- Commutative operators store operands in sorted, flattened form.
		- Associative operators never nest.
		- Functions never evaluate unless fully numeric.
		- Canonicalization flattens nested piecewise nodes.
		- Canonicalization prunes only syntactically unreachable branches
		  (literal false, duplicates, branches after literal true).
		- Canonicalization performs no semantic contradiction detection.
		- Branch order is preserved unless syntactic contradictions require pruning.
		- Canonicalization must not reorder non-commutative operators.

		------------------------------------------------------------------------
			Equation & Relational Invariants
		------------------------------------------------------------------------
		- Equations are not expressions; they are separate objects.
		- Relations are stored as literal comparison operator strings.
		- Arithmetic on equations applies operations to both sides.
		- Equation.lhs and Equation.rhs are always AST nodes.

		------------------------------------------------------------------------
			Rewrite Invariants
		------------------------------------------------------------------------
		- Rewrite never mutates nodes; all transformations return new trees.
		- Rewrite rules must terminate.
		- Rewrite must work on arbitrary trees (not assume canonical form).
		- Rewrite must not depend on Simplify or Canon.
		- Rewrite patterns match structural shapes only, not semantic meaning.

		------------------------------------------------------------------------
			Simplification Invariants
		------------------------------------------------------------------------
		- Simplify never mutates nodes.
		- Simplify always returns a new or original node.
		- Simplification rules must terminate.
		- Simplify recursively simplifies children before applying rules.
		- Simplify never changes mathematical meaning.
		- Simplify must not fold results that overflow IEEE-754’s exact integer range.

		------------------------------------------------------------------------
			Solving Invariants
		------------------------------------------------------------------------
		- Solvers return solution objects, not AST nodes.
		- Solvers never mutate input equations.
		- Solvers operate on canonicalized expressions.
		- Solvers never simplify the input equation (only output expressions).
		- Unsupported equation types return UnknownSolve.
		- Solvers must not implicitly simplify.
		- Solvers must propagate conditions faithfully.

		------------------------------------------------------------------------
			Expression Object Model Invariants
		------------------------------------------------------------------------
		- Expression objects never store raw Lua values; they wrap AST nodes.
		- Expression methods never mutate underlying nodes.

		------------------------------------------------------------------------
			Complex Number Invariants
		------------------------------------------------------------------------
		- Complex AST nodes are symbolic.
		- Complex numeric objects are numeric.
		- Complex AST nodes store real and imag as AST nodes.

		------------------------------------------------------------------------
			Factorization Invariants
		------------------------------------------------------------------------
		- N/A for now.
]]

-- the require chain
Util       = require(script.Util)
Node       = require(script.Node)
Token      = require(script.Token)
Parser     = require(script.Parser)
Canon      = require(script.Canon)
Simplify   = require(script.Simplify)
Diff       = require(script.Diff)
Eval       = require(script.Eval)
Factor     = require(script.Factor)
Rewrite    = require(script.Rewrite)
Substitute = require(script.Substitute)
Print      = require(script.Print)
Arithmetic = require(script.Arithmetic)
UserFunctions = require(script.UserFunctions)
UserConstants = require(script.UserConstants)
Assume = require(script.Assume)
Equation = require(script.Equation)
Expression = require(script.Expression)
Solve = require(script.Solve)
Complex = require(script.Complex)
Expand = require(script.Expand)

-- Expose rules for external API use.
rules_algebraic = require(script.Rewrite.rules_algebraic)

local nowayCAS = {
	Util = Util,
	Node = Node,
	Token = Token,
	Parser = Parser,
	Canon = Canon,
	Simplify = Simplify,
	Diff = Diff,
	Eval = Eval,
	Factor = Factor,
	Rewrite = Rewrite,
	Substitute = Substitute,
	Print = Print,
	Arithmetic = Arithmetic,
	UserFunctions = UserFunctions,
	UserConstants = UserConstants,
	Assume = Assume,
	Equation = Equation,
	Expression = Expression,
	Solve = Solve,
	Complex = Complex,
	Expand = Expand
}

-------------------------------------------------------
-- API Helpers
-------------------------------------------------------

-- Converts v into a node if possible.
local function asNode(v)
	if type(v) == "table" and v.kind then
		return v
	end

	if type(v) == "table" and v.node then
		return v.node
	end

	if type(v) == "number" then
		return Node.Num(tostring(v))
	end

	if type(v) == "string" then
		local tokens = Token._tokenize(v)
		return Parser.parse(tokens)
	end

	error("Cannot convert to node: " .. typeof(v))
end

-------------------------------------------------------
-- Public API
-------------------------------------------------------
-- Generic API

-- Converts a value (including complex numbers) into a human-readable string.
function nowayCAS.valueToString(x)
	return Print._value(x)
end

-------------------------------------------------------
-- Node Manipulation
-------------------------------------------------------

-- Parses a string to an expression or an equation.
-- If the string has a relation (=, >=, >, etc), it constructs an equation object
-- Else, it constructs an expression object
function nowayCAS.new(str)
	-- detect top-level relation
	local lhs, rel, rhs = Util.detectRelation(str)

	if rel then
		-- parse each side as an expression
		local leftExpr = nowayCAS.newExpression(lhs)
		local rightExpr = nowayCAS.newExpression(rhs)

		-- build equation
		return Equation.new(leftExpr.node, rightExpr.node, rel)
	end

	-- normal expression if not equation
	return nowayCAS.newExpression(str)
end

-- Returns the derivative of an AST with respect to a variable.
function nowayCAS.diff(node, var)
	return Diff.diff(node, var or "x")
end

-- Returns the n-th derivative of an AST with respect to a variable.
function nowayCAS.diffN(node, var, n)
	return Diff.diffN(node, var or "x", n)
end

-- Returns a number of the AST to be evaluated with an environment table.
-- The environment table contains a key which is the variable name, which a value that is a native Lua number.
-- For example: { x = 2, y = math.pi }
function nowayCAS.eval(node, env)
	return Eval.eval(node, env or {})
end

-- Returns the AST in simplified form.
function nowayCAS.simplify(node)
	node = Rewrite.apply(node, rules_algebraic.simplify)
	node = Simplify.simplifyDeep(node)
	node = Canon.canonical(node)

	return node
end

-- Returns the AST in expanded form.
function nowayCAS.expand(node)
	return Expand.expandDeep(node)
end

-- Returns the AST in factorized form.
function nowayCAS.factor(node)
	return Factor.factor(node)
end

-- Returns an AST with variables subsituted according to the map.
-- The map contains a key that is the variable name, with a value containing another AST or string which it will be converted to.
-- For example: { x = AST1, y = AST2 }
function nowayCAS.substitute(node, map)
	for key, value in pairs(map) do
		map[key] = asNode(value)
	end
	
	return nowayCAS.Substitute.apply(node, map)
end

-------------------------------------------------------
-- Pretty Printing + Other Outputs
-------------------------------------------------------

-- Returns the AST converted into a pure string.
function nowayCAS.toString(node)
	return Print._toString(node)
end

-- Returns the AST converted into LaTeX format in string.
function nowayCAS.toLatex(node)
	return Print._toLatex(node)
end

-- Returns the AST converted into a DAG format.
function nowayCAS.toDAGString(node)
	return Print._toDAGString(node)
end

-- Returns the AST converted into an AST Representation (for debug purposes).
-- Index the result with indented or raw to get its result.
-- Indented: Returns the formatted table.
-- Raw: Returns the luau table.
function nowayCAS.toASTRepresentation(node)
	return Print._toASTRepresentation(node)
end

-------------------------------------------------------
-- User-defined Functions + Constants API
-------------------------------------------------------

-- Defines a user-defined function.
-- Name: the name of the function, eg: 'f' = "f(...params)" when called.
-- Params: the parameters to substitute into the bodyString.
-- bodyString: the contents of the function as an AST node or string, eg: "7x + 3"
-- Eg: f(7, 4) = (2*(3y + 7x)) / 3 (x, y are params, f is name, (2*(3y + 7x)) / 3 is bodyAST).
function nowayCAS.defineFunction(name, params, bodyAST)
	UserFunctions.define(name, params, asNode(bodyAST))
end

-- Defines a user-defined constant.
-- Name: the name of the constant.
-- Value: the value that the constant will hold.
function nowayCAS.defineConstant(name, value)
	UserConstants.define(name, value)
end

-------------------------------------------------------
-- Assumptions External API
-------------------------------------------------------

-- Adds an assumption to a variable.
function nowayCAS.assume(var, property)
	Assume.add(var, property)
end

-- Removes a specific assumption from a variable.
function nowayCAS.unassume(var, property)
	Assume.remove(var, property)
end

-- Removes all assumptions associated with a variable.
function nowayCAS.clearVarAssumptions(var)
	Assume.clear(var)
end

-- Clears all assumptions for all variables.
function nowayCAS.clearAssumptions()
	Assume.reset()
end

-- Returns a read‑only table of all active assumptions.
function nowayCAS.assumptions()
	return Assume.dump()
end

-- Temporarily applies assumptions for the duration of fn. 
-- Restores previous assumptions afterward.
-- Parameter tbl is a table with the key as the variable name and the value is a list of temporary assumptions.
-- Eg: table = {x = {"integer", "positive"}, y = ...}

-- doesn't work, commented for now.
--[[function nowayCAS.withAssumptions(tbl, fn)
	return Assume.with(tbl, fn)
end]]

-- Returns true if the variable satisfies the property, directly or through implication.
function nowayCAS.is(var, property)
	return Assume.is(var, property)
end

-- Returns true only if the variable explicitly has the property (no implication).
function nowayCAS.hasAssumption(var, property)
	return Assume.has(var, property)
end

-- Replaces all assumptions for a variable with the provided list of tags.
function nowayCAS.setAssumptions(var, tags)
	Assume.set(var, tags)
end

-------------------------------------------------------
-- Public API - Expression Objects
-------------------------------------------------------

-- Parses the string into a new expression.
function nowayCAS.newExpression(str)
	local tokens = Token._tokenize(str)
	local ast = Parser.parse(tokens)
	return Expression.new(ast)
end

-------------------------------------------------------
-- Public API - Equation Objects
-------------------------------------------------------

-- Creates a new equation.
function nowayCAS.newEquation(lhsExpr, rhsExpr, rel)
	return Equation.new(asNode(lhsExpr), asNode(rhsExpr), rel)
end

-- Creates a new equal equation with two expressions.
function nowayCAS.newEqual(lhs, rhs) return Equation.eq(asNode(lhs), asNode(rhs)) end

-- Creates a new not-equal equation with two expressions.
function nowayCAS.newNotEqual(lhs, rhs) return Equation.neq(asNode(lhs), asNode(rhs)) end

-- Creates a new less-than equation with two expressions.
function nowayCAS.newLessThan(lhs, rhs) return Equation.lt(asNode(lhs), asNode(rhs))  end

-- Creates a new less-than-or-equal-to equation with two expressions.
function nowayCAS.newLessThanOrEqual(lhs, rhs) return Equation.le(asNode(lhs), asNode(rhs)) end

-- Creates a new greater-than equation with two expressions.
function nowayCAS.newGreaterThan(lhs, rhs) return Equation.gt(asNode(lhs), asNode(rhs))  end

-- Creates a new greater-than-or-equal-to equation with two expressions.
function nowayCAS.newGreaterThanOrEqual(lhs, rhs) return Equation.ge(asNode(lhs), asNode(rhs)) end

-- Returns a solve, solveset table, or other special table from solving the equation for a variable.
-- The variable must be a single variable node.
function nowayCAS.solveEquation(expr, var)
	return Solve.solve(expr, asNode(var))
end

-- Returns a solve, solveset table, or other special table from solving the equation for a variable.
-- The variable must be a single variable node.
function Equation:solve(var)
	return Solve.solve(self, asNode(var))
end

-------------------------------------------------------
-- Metamethods - Equation
-------------------------------------------------------

-- Returns the equation converted into a pure string.
function Equation.__tostring(a)
	return a:toString()
end

-- Returns an equation added by an expression.
function Equation.__add(a, b)
	return Equation.apply_op(a, "add", b)
end

-- Returns an equation subtracted by an expression.
function Equation.__sub(a, b)
	return Equation.apply_op(a, "sub", b)
end

-- Returns an equation multiplied by an expression.
function Equation.__mul(a, b)
	return Equation.apply_op(a, "mul", b)
end

-- Returns an equation divided by an expression.
function Equation.__div(a, b)
	return Equation.apply_op(a, "div", b)
end

-- Returns an equation powered by an expression
function Equation.__pow(a, b)
	return Equation.apply_op(a, "pow", b)
end

-- Returns the negated value of the equation.
function Equation.__unm(a)
	return a:negate()
end

-------------------------------------------------------
-- Metamethods - Expression
-------------------------------------------------------

-- Returns the expression converted into a pure string.
function Expression.__tostring(a)
	return nowayCAS.toString(a.node)
end

-- Returns an expression added by another thing.
function Expression.__add(a, b)
	if Util.isEquation(a) then return a + b end
	if Util.isEquation(b) then return b + a end 

	local result = nowayCAS.Arithmetic.add(a, b)
	return Expression.new(result)
end

-- Returns an expression subtracted by another thing.
function Expression.__sub(a, b)
	if Util.isEquation(a) then return a - b end
	if Util.isEquation(b) then return b - a end

	local result = nowayCAS.Arithmetic.sub(a, b)
	return Expression.new(result)
end

-- Returns an expression multiplied by another thing.
function Expression.__mul(a, b)
	if Util.isEquation(a) then return a * b end
	if Util.isEquation(b) then return b * a end

	local result = nowayCAS.Arithmetic.mul(a, b)
	return Expression.new(result)
end

-- Returns an expression divided by another thing.
function Expression.__div(a, b)
	if Util.isEquation(a) then return a / b end
	if Util.isEquation(b) then return b / a end

	local result = nowayCAS.Arithmetic.div(a, b)
	return Expression.new(result)
end

-- Returns an expression powered by another thing
function Expression.__pow(a, b)
	if Util.isEquation(a) then return a ^ b end
	if Util.isEquation(b) then return b ^ a end

	local result = nowayCAS.Arithmetic.pow(a, b)
	return Expression.new(result)
end

-- Returns the negated value of the expression.
function Expression.__unm(a)
	local result = nowayCAS.Arithmetic.neg(a)
	return Expression.new(result)
end

-------------------------------------------------------

-- Versioning
nowayCAS.VERSION = setmetatable({
	major = 0,
	minor = 14,
	patch = 1,
}, {
	__tostring = function(v)
		return string.format("%d.%d.%d", v.major, v.minor, v.patch)
	end
})

-- export symbolic algebra
return nowayCAS