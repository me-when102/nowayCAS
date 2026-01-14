local Expression = {}
Expression.__index = Expression

local Simplify = require(script.Parent.Simplify)
local Diff = require(script.Parent.Diff)
local Factor = require(script.Parent.Factor)
local Rewrite = require(script.Parent.Rewrite)
local Substitute = require(script.Parent.Substitute)
local Eval = require(script.Parent.Eval)
local Print = require(script.Parent.Print)
local Util = require(script.Parent.Util)
local Assume = require(script.Parent.Assume)
local Solve = require(script.Parent.Solve)
local Canon = require(script.Parent.Canon)
local Expand = require(script.Parent.Expand)

local rules_algebraic = require(script.Parent.Rewrite.rules_algebraic)

-------------------------------------------------------
-- Expressions
-------------------------------------------------------

-- Creates an expression.
function Expression.new(node)
	return setmetatable({ type = "expression", node = node }, Expression)
end

-- Returns the derivative of an expression with respect to a variable.
function Expression:diff(var)
	local raw = Diff.diff(self.node, var or "x")
	return Expression.new(Simplify.simplifyDeep(raw))
end

-- Returns the n-th derivative of an expression with respect to a variable.
function Expression:diffN(var, n)
	local raw = Diff.diffN(self.node, var or "x", n)
	return Expression.new(Simplify.simplifyDeep(raw))
end

-- Returns the expression in simplified form.
function Expression:simplify()
	local node = self.node

	node = Rewrite.apply(node, rules_algebraic.simplify)
	node = Simplify.simplifyDeep(node)
	node = Canon.canonical(node)

	return Expression.new(node)
end


-- Returns the expression in expanded form.
function Expression:expand()
	return Expression.new(Expand.expandDeep(self.node))
end

-- Returns the expression in factorized form.
function Expression:factor()
	return Expression.new(Factor.factor(self.node))
end

-- Returns an expression with variables subsituted according to the map.
-- The map contains a key that is the variable name, with a value containing another AST node which it will be converted to.
-- For example: { x = expr1.node, y = expr2.node }
function Expression:substitute(map)
	return Expression.new(Substitute.apply(self.node, map))
end

-- Returns a number of the expression to be evaluated with an environment table.
-- The environment table contains a key which is the variable name, which a value that is a native Lua number.
-- For example: { x = 2, y = math.pi }
function Expression:eval(env)
	return Eval.eval(self.node, env)
end

-- Returns the expression converted into a pure string.
function Expression:toString()
	return Print._toString(self.node)
end

-- Returns the expression converted into LaTeX format in string.
function Expression:toLatex()
	return Print._toLatex(self.node)
end

-- Returns the expression converted into a DAG format.
function Expression:toDAGString()
	return Print._toDAGString(self.node)
end

-- Returns the expression converted into an AST Representation (for debug purposes).
-- Index the result with indented or raw to get its result.
-- Indented: Returns the formatted table.
-- Raw: Returns the luau table.
function Expression:toASTRepresentation()
	return Print._toASTRepresentation(self.node)
end

-- Determines if all variables of the expression satisfy the property.
function Expression:is(property)
	local vars = Util.collectVars(self.node)

	-- No variables -> expression is trivially in the domain
	if #vars == 0 then
		return true
	end

	for _, var in ipairs(vars) do
		if not Assume.is(var, property) then
			return false
		end
	end

	return true
end

-- Determines if the variable in the expression satisfy the property.
function Expression:varIs(var, property)
	return Assume.is(var, property)
end

-- Returns a solve, solveset table, or other special table from solving the expression (converted into an equation) for a variable.
-- The variable must be a single variable node.
function Expression:solve(var)
	return Solve.solve(self.node, var)
end

-- Get variables for the expression.
function Expression:variables()
	return Util.collectVars(self.node)
end

-- The Expression sub-library.
return Expression