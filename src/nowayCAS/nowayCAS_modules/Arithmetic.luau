local Arithmetic = {}

local Node = require(script.Parent.Node)
local Canon = require(script.Parent.Canon)

local type = type

-------------------------------------------------------
-- Arithmetic
-- Allows handling of two AST expressions
-------------------------------------------------------

-- Coercion helper
-- Converts any value into an AST node if possible.
local function coerce(value)
	-- Expression object
	if type(value) == "table" and value.node then
		return value.node
	end

	-- AST node
	if type(value) == "table" and value.kind then
		return value
	end

	-- number
	if type(value) == "number" then
		return Node.Num(value)
	end

	error("Cannot coerce value into AST node: " .. tostring(value))
end

-- Adds two AST expressions.
function Arithmetic.add(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Canon.canonical(Node.Op("+", nodeA, nodeB))
end

-- Subtracts two AST expressions.
function Arithmetic.sub(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Canon.canonical(Node.Op("-", nodeA, nodeB))
end

-- Multiplies two AST expressions.
function Arithmetic.mul(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Canon.canonical(Node.Op("*", nodeA, nodeB))
end

-- Divides two AST expressions.
function Arithmetic.div(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Canon.canonical(Node.Op("/", nodeA, nodeB))
end

-- Returns the result of an AST expression powered by another AST expression.
function Arithmetic.pow(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Canon.canonical(Node.Op("^", nodeA, nodeB))
end

-- Returns the negated value of an AST expression
function Arithmetic.neg(node)
	node = coerce(node)
	return Canon.canonical(Node.Op("*", Node.Num("-1"), node))
end

-- The Arithmetic sub-library.
return Arithmetic