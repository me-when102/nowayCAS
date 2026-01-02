local Arithmetic = {}

local Node = require(script.Parent.Node)

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

-- Applies local canonical rules to a newly constructed AST node.
function Arithmetic._canonical(node)
	local kind = node.kind
	if kind ~= "op" then
		return node
	end

	local op = node.op
	local A = node.left
	local B = node.right

	-------------------------------------------------------
	-- ADDITION RULES
	-------------------------------------------------------
	if op == "+" then
		-- 0 + x → x
		if A.kind == "num" and A.value == 0 then
			return B
		end
		-- x + 0 → x
		if B.kind == "num" and B.value == 0 then
			return A
		end
		return node
	end

	-------------------------------------------------------
	-- SUBTRACTION RULES
	-------------------------------------------------------
	if op == "-" then
		-- x - 0 → x
		if B.kind == "num" and B.value == 0 then
			return A
		end
		return node
	end

	-------------------------------------------------------
	-- MULTIPLICATION RULES
	-------------------------------------------------------
	if op == "*" then
		-- 0 * x → 0
		if A.kind == "num" and A.value == 0 then
			return Node.Num(0)
		end
		-- x * 0 → 0
		if B.kind == "num" and B.value == 0 then
			return Node.Num(0)
		end

		-- 1 * x → x
		if A.kind == "num" and A.value == 1 then
			return B
		end
		-- x * 1 → x
		if B.kind == "num" and B.value == 1 then
			return A
		end

		-- (-1) * num(n) → num(-n)
		if A.kind == "num" and A.value == -1 and B.kind == "num" then
			return Node.Num(-B.value)
		end

		-- Double negation collapse:
		-- (-1) * ((-1) * x) → x
		if A.kind == "num" and A.value == -1 then
			if B.kind == "op" and B.op == "*" then
				local BL = B.left
				if BL.kind == "num" and BL.value == -1 then
					return B.right
				end
			end
		end

		return node
	end

	-------------------------------------------------------
	-- DIVISION RULES
	-------------------------------------------------------
	if op == "/" then
		-- x / 1 → x
		if B.kind == "num" and B.value == 1 then
			return A
		end
		return node
	end

	-------------------------------------------------------
	-- POWER RULES
	-------------------------------------------------------
	if op == "^" then
		-- x^1 → x
		if B.kind == "num" and B.value == 1 then
			return A
		end
		-- x^0 → 1 (domain issues ignored for now)
		if B.kind == "num" and B.value == 0 then
			return Node.Num(1)
		end
		return node
	end

	return node
end

-- Adds two AST expressions.
function Arithmetic.add(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Arithmetic._canonical(Node.Op("+", nodeA, nodeB))
end

-- Subtracts two AST expressions.
function Arithmetic.sub(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Arithmetic._canonical(Node.Op("-", nodeA, nodeB))
end

-- Multiplies two AST expressions.
function Arithmetic.mul(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Arithmetic._canonical(Node.Op("*", nodeA, nodeB))
end

-- Divides two AST expressions.
function Arithmetic.div(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Arithmetic._canonical(Node.Op("/", nodeA, nodeB))
end

-- Returns the result of an AST expression powered by another AST expression.
function Arithmetic.pow(nodeA, nodeB)
	nodeA = coerce(nodeA)
	nodeB = coerce(nodeB)
	return Arithmetic._canonical(Node.Op("^", nodeA, nodeB))
end

-- Returns the negated value of an AST expression
function Arithmetic.neg(node)
	node = coerce(node)
	return Arithmetic._canonical(Node.Op("*", Node.Num("-1"), node))
end

-- The Arithmetic sub-library.
return Arithmetic