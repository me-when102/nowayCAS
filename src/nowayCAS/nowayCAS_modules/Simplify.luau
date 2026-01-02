local Simplify = {}
local SIMPLIFY_CACHE = {}

local Canon = require(script.Parent.Canon)
local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)

local tonumber = tonumber
local tostring = tostring

-------------------------------------------------------
-- Simplifier
-- Applies algebraic rewrite rules to AST nodes.
-- Invariants:
--   - Simplification never mutates nodes.
--   - Always returns a new or original node.
--   - Recursively simplifies children before applying rules.
-------------------------------------------------------

function Simplify.simplifyDeep(node, maxSteps)
	maxSteps = maxSteps or 10000
	local steps = 0
	
	while steps < maxSteps do
		local next = Simplify.simplify(node)
		if Util.nodeEquals(next, node) then
			return node
		end
		node = next
		steps += 1
	end
	
	return node
end

-- Simplifies a node.
function Simplify.simplify(node)
	-- DAG-aware memoization
	local cached = SIMPLIFY_CACHE[node]
	if cached then
		return cached
	end

	local simplified
	if node.kind == "num" then
		simplified = node
	elseif node.kind == "var" then
		simplified = node
	elseif node.kind == "func" then
		simplified = Simplify._simplifyFunc(node)
	elseif node.kind == "op" then
		simplified = Simplify._simplifyOp(node)
	else
		error("Simplify: Unknown node kind '" .. tostring(node.kind) .. "'")
	end
	
	-- Canonicalize AFTER simplification
	simplified = Canon.canonical(simplified)
	
	-- Store in memo table
	SIMPLIFY_CACHE[node] = simplified
	return simplified
end

-- Simplifies the function node.
function Simplify._simplifyFunc(node)
	local arg = Simplify.simplify(node.arg)
	local name = node.name

	-------------------------------------------------------
	-- Function-specific simplifications
	-------------------------------------------------------

	-------------------------------------------------------
	-- Trig Identities
	-------------------------------------------------------

	-- sin(0) -> 0
	if name == "sin" and arg.kind == "num" and arg.value == "0" then
		return Node.Num("0")
	end

	-- cos(0) -> 1
	if name == "cos" and arg.kind == "num" and arg.value == "0" then
		return Node.Num("1")
	end

	-- exp(0) -> 1
	if name == "exp" and arg.kind == "num" and arg.value == "0" then
		return Node.Num("1")
	end
	
	-------------------------------------------------------
	-- Reciprocal Trig Identities
	-------------------------------------------------------

	-- sec(0) -> 1
	if name == "sec" and arg.kind == "num" and arg.value == "0" then
		return Node.Num("1")
	end

	-- csc(0) is undefined, so no simplification

	-- cot(0) is undefined, so no simplification

	-- sin(acos(x)) etc. handled above; here we only collapse reciprocals:
	-- sec(x) where arg is cos^-1 form is handled in diff layer, not here.

	-------------------------------------------------------
	-- Inverse Trig Identities
	-------------------------------------------------------

	-- asin(0) -> 0
	if name == "asin" and arg.kind == "num" and arg.value == "0" then
		return Node.Num(0)
	end

	-- acos(1) -> 0
	if name == "acos" and arg.kind == "num" and arg.value == "1" then
		return Node.Num(0)
	end

	-- atan(0) -> 0
	if name == "atan" and arg.kind == "num" and arg.value == "0" then
		return Node.Num(0)
	end

	-------------------------------------------------------
	-- Hyberbolic Identities
	-------------------------------------------------------

	-- sinh(0) -> 0
	if name == "sinh" and arg.kind == "num" and arg.value == "0" then
		return Node.Num(0)
	end

	-- cosh(0) -> 1
	if name == "cosh" and arg.kind == "num" and arg.value == "0" then
		return Node.Num(1)
	end

	-- tanh(0) -> 0
	if name == "tanh" and arg.kind == "num" and arg.value == "0" then
		return Node.Num(0)
	end
	
	-------------------------------------------------------
	-- Reciprocal Hyperbolic Identities
	-------------------------------------------------------

	-- sech(0) -> 1 / cosh(0) -> 1
	if name == "sech" and arg.kind == "num" and arg.value == "0" then
		return Node.Num("1")
	end

	-- csch(0) undefined -> no simplification

	-- coth(0) undefined -> no simplification

	-------------------------------------------------------
	-- Inverse Hyberbolic Identities
	-------------------------------------------------------

	-- asinh(0) -> 0
	if name == "asinh" and arg.kind == "num" and arg.value == "0" then
		return Node.Num(0)
	end

	-- atanh(0) -> 0
	if name == "atanh" and arg.kind == "num" and arg.value == "0" then
		return Node.Num(0)
	end
	
	-------------------------------------------------------
	-- Natural Logarithm and Exponential Identities
	-------------------------------------------------------

	-- ln(1) -> 0
	if name == "ln" and arg.kind == "num" and arg.value == "1" then
		return Node.Num("0")
	end

	-- ln(exp(x)) -> x
	if name == "ln"
		and arg.kind == "func"
		and arg.name == "exp" then
		return arg.arg
	end

	-- exp(ln(x)) -> x
	if name == "exp"
		and arg.kind == "func"
		and arg.name == "ln" then
		return arg.arg
	end

	-------------------------------------------------------
	-- Square Root Identities
	-------------------------------------------------------

	-- sqrt(0) -> 0
	if name == "sqrt" and arg.kind == "num" and arg.value == "0" then
		return Node.Num("0")
	end

	-- sqrt(1) -> 1
	if name == "sqrt" and arg.kind == "num" and arg.value == "1" then
		return Node.Num("1")
	end

	-- sqrt(x^2) -> x
	if name == "sqrt"
		and arg.kind == "op"
		and arg.op == "^"
		and arg.right.kind == "num"
		and arg.right.value == "2" then
		return arg.left
	end
	
	-------------------------------------------------------
	-- Miscellaneous Identities
	-------------------------------------------------------

	-- abs(0) -> 0
	if name == "abs" and arg.kind == "num" and arg.value == "0" then
		return Node.Num(0)
	end

	-- floor(n) -> n for integers
	if name == "floor" and arg.kind == "num" and math.floor(tonumber(arg.value)) == tonumber(arg.value) then
		return arg
	end

	-- ceil(n) -> n for integers
	if name == "ceil" and arg.kind == "num" and math.ceil(tonumber(arg.value)) == tonumber(arg.value) then
		return arg
	end

	-------------------------------------------------------
	-- Other Identities
	-------------------------------------------------------

	-- sin(asin(x)) -> x
	if name == "sin"
		and arg.kind == "func"
		and arg.name == "asin" then
		return arg.arg
	end

	-- cos(acos(x)) -> x
	if name == "cos"
		and arg.kind == "func"
		and arg.name == "acos" then
		return arg.arg
	end

	-- tan(atan(x)) -> x
	if name == "tan"
		and arg.kind == "func"
		and arg.name == "atan" then
		return arg.arg
	end

	-- abs(abs(x)) -> abs(x)
	if name == "abs"
		and arg.kind == "func"
		and arg.name == "abs" then
		return arg
	end

	-------------------------------------------------------
	-- No function-specific rule applied
	-------------------------------------------------------
	if arg == node.arg then
		return node
	end

	return Node.Func(name, arg)
end

-- Simplifies the operator node.
function Simplify._simplifyOp(node)
	local left = Simplify.simplify(node.left)
	local right = Simplify.simplify(node.right)
	local op = node.op

	-------------------------------------------------------
	-- Constant folding
	-------------------------------------------------------
	if left.kind == "num" and right.kind == "num" then
		return Simplify._foldConstants(op, left.value, right.value)
	end

	-------------------------------------------------------
	-- Algebraic identities and structural simplifications
	-------------------------------------------------------

	-------------------------------------------------------
	-- ADDITION
	-------------------------------------------------------
	if op == "+" then
		-- x + 0 -> x
		if right.kind == "num" and right.value == "0" then return left end
		if left.kind == "num" and left.value == "0" then return right end

		-- Flatten right: x + (y + z) -> (x + y + z)
		if right.kind == "op" and right.op == "+" then
			return Node.Op("+",
				Node.Op("+", left, right.left),
				right.right
			)
		end

		-- Flatten left: (x + y) + z -> (x + y + z)
		if left.kind == "op" and left.op == "+" then
			return Node.Op("+",
				left.left,
				Node.Op("+", left.right, right)
			)
		end

		-- Combine numeric terms: (a + b) + c -> Num(a+b+c)
		if left.kind == "op" and left.op == "+"
			and left.left.kind == "num"
			and left.right.kind == "num"
			and right.kind == "num" then

			local sum = tonumber(left.left.value)
				+ tonumber(left.right.value)
				+ tonumber(right.value)

			return Node.Num(tostring(sum))
		end

		-- (x + a) + b -> x + (a+b)
		if left.kind == "op" and left.op == "+"
			and left.right.kind == "num"
			and right.kind == "num" then

			local sum = tonumber(left.right.value) + tonumber(right.value)
			return Node.Op("+", left.left, Node.Num(tostring(sum)))
		end

		-- x + (-1)*y -> x - y
		if right.kind == "op" and right.op == "*"
			and right.left.kind == "num" and right.left.value == "-1" then

			return Node.Op("-", left, right.right)
		end
	end

	-------------------------------------------------------
	-- SUBTRACTION
	-------------------------------------------------------
	if op == "-" then
		-- x - 0 -> x
		if right.kind == "num" and right.value == "0" then
			return left
		end

		-- 0 - x -> -x
		if left.kind == "num" and left.value == "0" then
			return Node.Op("*", Node.Num("-1"), right)
		end

		-- Normalize subtraction: x - y -> x + (-1)*y
		return Node.Op("+",
			left,
			Node.Op("*", Node.Num("-1"), right)
		)
	end

	-------------------------------------------------------
	-- MULTIPLICATION
	-------------------------------------------------------
	if op == "*" then
		-- x * 1 -> x
		if right.kind == "num" and right.value == "1" then return left end
		if left.kind == "num" and left.value == "1" then return right end

		-- x * 0 -> 0
		if right.kind == "num" and right.value == "0" then return right end
		if left.kind == "num" and left.value == "0" then return left end

		-- (-1) * (-1) -> 1
		if left.kind == "num" and left.value == "-1"
			and right.kind == "num" and right.value == "-1" then
			return Node.Num("1")
		end

		-- (-1) * n -> -n
		if left.kind == "num" and left.value == "-1"
			and right.kind == "num" then
			return Node.Num(tostring(-tonumber(right.value)))
		end

		-- x * (-1) -> -x
		if right.kind == "num" and right.value == "-1" then
			return Node.Op("*", Node.Num("-1"), left)
		end

		-- Flatten right: x * (y * z) -> (x * y * z)
		if right.kind == "op" and right.op == "*" then
			return Node.Op("*",
				Node.Op("*", left, right.left),
				right.right
			)
		end

		-- Flatten left: (x * y) * z -> (x * y * z)
		if left.kind == "op" and left.op == "*" then
			return Node.Op("*",
				left.left,
				Node.Op("*", left.right, right)
			)
		end

		-- Combine numeric factors: (a * b) * c -> Num(a*b*c)
		if left.kind == "op" and left.op == "*"
			and left.left.kind == "num"
			and left.right.kind == "num"
			and right.kind == "num" then

			local prod = tonumber(left.left.value)
				* tonumber(left.right.value)
				* tonumber(right.value)

			return Node.Num(tostring(prod))
		end

		-- (x * a) * b -> x * (a*b)
		if left.kind == "op" and left.op == "*"
			and left.right.kind == "num"
			and right.kind == "num" then

			local prod = tonumber(left.right.value) * tonumber(right.value)
			return Node.Op("*", left.left, Node.Num(tostring(prod)))
		end

		-- 1/x * x -> 1 (reverse order)
		if left.kind == "op" and left.op == "/"
			and left.left.kind == "num" and left.left.value == "1"
			and Util.nodeEquals(left.right, right) then
			return Node.Num("1")
		end

		-- Negation propagation: (-1)*(u+v) -> (-u) + (-v)
		if left.kind == "num" and left.value == "-1"
			and right.kind == "op" and right.op == "+" then

			local negLeft = Node.Op("*", Node.Num("-1"), right.left)
			local negRight = Node.Op("*", Node.Num("-1"), right.right)

			return Node.Op("+",
				Simplify.simplify(negLeft),
				Simplify.simplify(negRight)
			)
		end
	end

	-------------------------------------------------------
	-- DIVISION
	-------------------------------------------------------

	if op == "/" then
		-- First: simplify children
		local left = Simplify.simplify(node.left)
		local right = Simplify.simplify(node.right)

		-------------------------------------------------------
		-- (u * 1) / v -> u / v
		-------------------------------------------------------
		if left.kind == "op" and left.op == "*" then
			if left.right.kind == "num" and left.right.value == "1" then
				return Node.Op("/", left.left, right)
			end
			if left.left.kind == "num" and left.left.value == "1" then
				return Node.Op("/", left.right, right)
			end
		end

		-------------------------------------------------------
		-- Reciprocal trig collapsing
		-------------------------------------------------------

		-- 1 / cos(x) -> sec(x)
		if left.kind == "num" and left.value == "1"
			and right.kind == "func" and right.name == "cos" then
			return Node.Func("sec", right.arg)
		end

		-- 1 / sin(x) -> csc(x)
		if left.kind == "num" and left.value == "1"
			and right.kind == "func" and right.name == "sin" then
			return Node.Func("csc", right.arg)
		end

		-- cos(x) / sin(x) -> cot(x)
		if left.kind == "func" and left.name == "cos"
			and right.kind == "func" and right.name == "sin" then
			return Node.Func("cot", left.arg)
		end

		-------------------------------------------------------
		-- Hyperbolic versions
		-------------------------------------------------------

		-- 1 / cosh(x) -> sech(x)
		if left.kind == "num" and left.value == "1"
			and right.kind == "func" and right.name == "cosh" then
			return Node.Func("sech", right.arg)
		end

		-- 1 / sinh(x) -> csch(x)
		if left.kind == "num" and left.value == "1"
			and right.kind == "func" and right.name == "sinh" then
			return Node.Func("csch", right.arg)
		end

		-- cosh(x) / sinh(x) -> coth(x)
		if left.kind == "func" and left.name == "cosh"
			and right.kind == "func" and right.name == "sinh" then
			return Node.Func("coth", left.arg)
		end

		-------------------------------------------------------
		-- No rule matched -> return simplified division
		-------------------------------------------------------
		return Node.Op("/", left, right)
	end

	-------------------------------------------------------
	-- EXPONENTIATION
	-------------------------------------------------------
	if op == "^" then
		-- x^1 -> x
		if right.kind == "num" and right.value == "1" then
			return left
		end

		-- x^0 -> 1
		if right.kind == "num" and right.value == "0" then
			return Node.Num("1")
		end

		-- x^(-1) -> 1/x
		if right.kind == "num" and right.value == "-1" then
			return Node.Op("/", Node.Num("1"), left)
		end

		-- (x^a)^b -> x^(a*b)
		if left.kind == "op" and left.op == "^"
			and right.kind == "num"
			and left.right.kind == "num" then

			local newExp = tonumber(left.right.value) * tonumber(right.value)
			return Node.Op("^", left.left, Node.Num(tostring(newExp)))
		end
	end

	-------------------------------------------------------
	-- No simplification applied -> rebuild if needed
	-------------------------------------------------------
	if left == node.left and right == node.right then
		return node
	end

	return Node.Op(op, left, right)
end

--[[
    Constant folding helper.
    Given an operator and two numeric literal strings (a, b),
    evaluate the operation at simplification time and return
    a new Num node containing the computed result.

    Example:
        ("+", "2", "3") -> Num("5")
        ("*", "4", "7") -> Num("28")

    If either operand cannot be converted to a number,
    returns a normal Op node as a safe fallback.
]]
function Simplify._foldConstants(op, a, b)
	local na = tonumber(a)
	local nb = tonumber(b)

	if not na or not nb then
		-- Should never happen, but safe fallback
		return Node.Op(op, Node.Num(a), Node.Num(b))
	end

	if op == "+" then return Node.Num(tostring(na + nb)) end
	if op == "-" then return Node.Num(tostring(na - nb)) end
	if op == "*" then return Node.Num(tostring(na * nb)) end
	if op == "/" then return Node.Num(tostring(na / nb)) end
	if op == "^" then return Node.Num(tostring(na ^ nb)) end

	return Node.Op(op, Node.Num(a), Node.Num(b))
end

-- The Simplifier sub-library.
return Simplify