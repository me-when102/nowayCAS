-- nowayCAS: a symbolic algebra system module in the nowayCAS library

--[[

	Core invariants:
	    - All expressions are immutable trees.
	    - Node kinds: "num", "var", "op", "func".
	    - Operators are binary; functions are unary.
	    - No node ever stores parent references.
		- Unary minus is expressed as a multiplication node (left: -1, right: any)

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

Rules = require(script.Rewrite.Rules)

local nowayCAS = {
	Util = Util,
	Node = Node,
	Token = Token,
	Parser = Parser,
	Simplify = Simplify,
	Diff = Diff,
	Eval = Eval,
	Factor = Factor,
	Rewrite = Rewrite,
	Substitute = Substitute,
	Print = Print,
	Arithmetic = Arithmetic
}

-------------------------------------------------------
-- Caching
-------------------------------------------------------

-- table

local table_insert = table.insert
local table_remove = table.remove

-- other things

local type = type
local tonumber = tonumber
local tostring = tostring

-------------------------------------------------------
-- Public API
-- @@find_API
-------------------------------------------------------

-- expression instance
local Expression = {}
Expression.__index = Expression

-- nowayCAS public API

-- Parses a string into an expression AST
function nowayCAS.new(str)
	local tokens = Token._tokenize(str)
	local ast = Parser.parse(tokens)
	return Expression.new(ast)
end

-- Differentiate an expression.
function nowayCAS.diff(node, var)
	return Diff.diff(node, var or "x")
end

-- Evaluate an expression with an environment table.
function nowayCAS.eval(node, env)
	return Eval.eval(node, env or {})
end

-- Simplifies the AST.
function nowayCAS.simplify(node)
	return Simplify.simplifyDeep(node)
end

-- Expands the AST.
function nowayCAS.expand(node)
	return Rewrite.apply(node, Rules.expandRules)
end

-- Factorises the AST.
function nowayCAS.factor(node)
	return Factor.factor(node)
end

-- Substitutes the AST with a map.
function nowayCAS.substitute(node, map)
	return nowayCAS.Substitute.apply(node, map)
end

-- Converts the AST to a readable string.
function nowayCAS.toString(node)
	return Print._toString(node)
end

-- Converts the AST into a DAG print.
function nowayCAS.toDAGString(node)
	return Print._toDAGString(node)
end

-- Converts the AST into a string in LaTeX form.
function nowayCAS.toLatex(node)
	return Print._toLatex(node)
end

function nowayCAS.toASTRepresentation(node)
	return Print.toASTRepresentation(node)
end

-------------------------------------------------------
-- Public API - Expression Objects
-------------------------------------------------------

-- Creates an expression.
function Expression.new(node)
	return setmetatable({ node = node }, Expression)
end

-- Differentiate an expression.
function Expression:diff(var)
	local raw = nowayCAS.Diff.diff(self.node, var or "x")
	return Expression.new(nowayCAS.simplify(raw))
end

-- Simplifies the AST expression.
function Expression:simplify()
	return Expression.new(nowayCAS.simplify(self.node))
end

-- Expands the expression.
function Expression:expand()
	return Expression.new(nowayCAS.expand(self.node))
end

-- Factorizes the expression.
function Expression:factor()
	return Expression.new(nowayCAS.factor(self.node))
end

-- Substitutes the expression with a map.
function Expression:substitute(map)
	return Expression.new(nowayCAS.Substitute.apply(self.node, map))
end

-- Evaluate an expression with an environment table.
function Expression:eval(env)
	return nowayCAS.eval(self.node, env)
end

-- Converts the AST to a readable string.
function Expression:toString()
	return nowayCAS.toString(self.node)
end

-- Converts teh AST into a string in LaTeX form.
function Expression:toLatex()
	return nowayCAS.toLatex(self.node)
end

-- Converts the AST into a DAG print.
function Expression:toDAGString()
	return nowayCAS.toDAGString(self.node)
end

function Expression:toASTRepresentation()
	return nowayCAS.toASTRepresentation(self.node)
end

-------------------------------------------------------
-- Metamethods
-------------------------------------------------------

-- Converts the AST to a readable string (metamethod).
function Expression:__tostring()
	return nowayCAS.toString(self.node)
end

-- Adds an expression with a thing.
function Expression.__add(a, b)
	local result = nowayCAS.Arithmetic.add(a, b)
	return Expression.new(result)
end

-- Subtracts an expression with a thing.
function Expression.__sub(a, b)
	local result = nowayCAS.Arithmetic.sub(a, b)
	return Expression.new(result)
end

-- Multiplies an expression with a thing.
function Expression.__mul(a, b)
	local result = nowayCAS.Arithmetic.mul(a, b)
	return Expression.new(result)
end

-- Divides an expression with a thing.
function Expression.__div(a, b)
	local result = nowayCAS.Arithmetic.div(a, b)
	return Expression.new(result)
end

-- Returns an expression powered by a thing
function Expression.__pow(a, b)
	local result = nowayCAS.Arithmetic.pow(a, b)
	return Expression.new(result)
end

-- Returns the negated value of the expression.
function Expression.__unm(a)
	local result = nowayCAS.Arithmetic.neg(a)
	return Expression.new(result)
end

-------------------------------------------------------
return nowayCAS