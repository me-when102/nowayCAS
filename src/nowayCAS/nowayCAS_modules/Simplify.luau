local Simplify = {}
local SIMPLIFY_CACHE = {}

local Canon = require(script.Parent.Canon)
local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)
local Rewrite = require(script.Parent.Rewrite)
local Assume = require(script.Parent.Assume)

local rules_algebraic = require(script.Parent.Rewrite.rules_algebraic)

local tonumber = tonumber
local tostring = tostring
local table_insert = table.insert

-------------------------------------------------------
-- Simplifier
-- Applies algebraic rewrite rules to AST nodes.
-- Invariants:
--   - Simplification never mutates nodes.
--   - Always returns a new or original node.
--   - Recursively simplifies children before applying rules.
-------------------------------------------------------

local function toRat(n)
	if n.kind == "rat" then
		return n.num, n.den
	elseif n.kind == "num" then
		return tonumber(n.value), 1
	else
		return nil
	end
end

-- Performs a fixed-point simplification with optional map steps.
function Simplify.simplifyDeep(node, maxSteps)
	maxSteps = maxSteps or 20
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

	elseif node.kind == "const" then
		simplified = node

	elseif node.kind == "complex" then
		simplified = Simplify._simplifyComplex(node)

	elseif node.kind == "rat" then
		simplified = Canon.canonical(node)

	elseif node.kind == "func" then
		simplified = Simplify._simplifyFunc(node)

	elseif node.kind == "op" then
		simplified = Simplify._simplifyOp(node)
	elseif node.kind == "piecewise" then
		simplified = Simplify._simplifyPiecewise(node)

	else
		error("Simplify: Unknown node kind '" .. tostring(node.kind) .. "'")
	end

	-- Apply algebraic simplification.
	simplified = Rewrite.apply(simplified, rules_algebraic.simplify)

	-- Canonicalize AFTER simplification
	simplified = Canon.canonical(simplified)

	-- Store in memo table
	SIMPLIFY_CACHE[node] = simplified
	return simplified
end

-- Checks if the node has a value of zero.
local function isZero(n)
	return (n.kind == "num" and n.value == "0")
		or (n.kind == "rat" and n.num == 0)
end

-- Checks if the node has a value of one.
local function isOne(n)
	return (n.kind == "num" and n.value == "1")
		or (n.kind == "rat" and n.num == n.den)
end

-- Checks if the node has a value of negative one.
local function isNegOne(n)
	return (n.kind == "num" and n.value == "-1")
		or (n.kind == "rat" and n.num == -n.den)
end

-- Checks if the node is numeric or rational.
local function isNumeric(n)
	return n.kind == "num" or n.kind == "rat"
end

-- Checks if the node is constant and is true.
local function isTrue(n)
	return n.kind == "const" and n.name == "true"
end

-- Checks if the node is constant and is false.
local function isFalse(n)
	return n.kind == "const" and n.name == "false"
end

-- Simplify for Factorial
local function simplifyFactorial(node)
	-- Simplify the argument first
	local arg = Simplify.simplify(node.args[1])

	-- Rebuild node with simplified argument
	node = Node.Func("factorial", { arg })

	-- factorial of a numeric literal
	if arg.kind == "num" then
		local n = tonumber(arg.value)

		-- Only simplify non-negative integers
		if n and n >= 0 and n % 1 == 0 then

			-- 0! and 1! -> 1
			if n == 0 or n == 1 then
				return Node.Num("1")
			end

			return Node.Num(tostring(Util.factorial(n)))
		end

		return node
	end

	-- factorial(factorial(n)) where inner is numeric
	if arg.kind == "func" and arg.name == "factorial" then
		local inner = arg.args[1]

		if inner.kind == "num" then
			local n = tonumber(inner.value)

			if n and n >= 0 and n % 1 == 0 then
				-- factorial(factorial(n)) -> factorial(n!)
				return Node.Func("factorial", {
					Node.Num(tostring(Util.factorial(n)))
				})
			end
		end
	end

	-- leave as factorial(arg)
	return node
end

-- Simplifies the function node.
function Simplify._simplifyFunc(node)
	local name = node.name

	-- Backward compatible: support old node.arg
	local args = node.args

	-- Simplify all arguments
	local newArgs = {}

	for i, a in ipairs(args) do
		local sa = Simplify.simplify(a)
		newArgs[i] = sa
	end

	-- get arguments
	local arg = newArgs[1]

	if not arg then
		-- zero-arg function: nothing to do
		return node
	end

	-- get second argument, not guaranteed
	local arg2 = newArgs[2]

	-------------------------------------------------------
	-- Function-specific simplifications
	-------------------------------------------------------

	-------------------------------------------------------
	-- Trig Identities
	-------------------------------------------------------

	-- sin(0) -> 0
	if name == "sin" and isZero(arg) then
		return Node.Num("0")
	end

	-- cos(0) -> 1
	if name == "cos" and isZero(arg) then
		return Node.Num("1")
	end

	-- exp(0) -> 1
	if name == "exp" and isZero(arg) then
		return Node.Num("1")
	end

	-------------------------------------------------------
	-- Reciprocal Trig Identities
	-------------------------------------------------------

	-- sec(0) -> 1
	if name == "sec" and isZero(arg) then
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
	if name == "asin" and isZero(arg) then
		return Node.Num(0)
	end

	-- acos(1) -> 0
	if name == "acos" and isOne(arg) then
		return Node.Num(0)
	end

	-- atan(0) -> 0
	if name == "atan" and isZero(arg) then
		return Node.Num(0)
	end

	-------------------------------------------------------
	-- Hyberbolic Identities
	-------------------------------------------------------

	-- sinh(0) -> 0
	if name == "sinh" and isZero(arg) then
		return Node.Num(0)
	end

	-- cosh(0) -> 1
	if name == "cosh" and isZero(arg) then
		return Node.Num(1)
	end

	-- tanh(0) -> 0
	if name == "tanh" and isZero(arg) then
		return Node.Num(0)
	end

	-------------------------------------------------------
	-- Reciprocal Hyperbolic Identities
	-------------------------------------------------------

	-- sech(0) -> 1 / cosh(0) -> 1
	if name == "sech" and isZero(arg) then
		return Node.Num("1")
	end

	-- csch(0) undefined -> no simplification

	-- coth(0) undefined -> no simplification

	-------------------------------------------------------
	-- Inverse Hyberbolic Identities
	-------------------------------------------------------

	-- asinh(0) -> 0
	if name == "asinh" and isZero(arg) then
		return Node.Num("0")
	end

	-- atanh(0) -> 0
	if name == "atanh" and isZero(arg) then
		return Node.Num("0")
	end

	-------------------------------------------------------
	-- Natural Logarithm and Exponential Identities
	-------------------------------------------------------

	-- ln(1) -> 0
	if name == "ln" and isOne(arg) then
		return Node.Num("0")
	end

	-- ln(exp(x)) -> x
	if name == "ln"
		and arg.kind == "func"
		and arg.name == "exp" then
		return arg.args[1]
	end

	-- exp(ln(x)) -> x
	if name == "exp"
		and arg.kind == "func"
		and arg.name == "ln" then
		return arg.args[1]
	end

	-------------------------------------------------------
	-- Square Root Identities
	-------------------------------------------------------

	-- sqrt(0) -> 0
	if name == "sqrt" and isZero(arg) then
		return Node.Num("0")
	end

	-- sqrt(1) -> 1
	if name == "sqrt" and isOne(arg) then
		return Node.Num("1")
	end

	-- sqrt(x^2) -> x or -x or abs(x)
	if name == "sqrt"
		and arg.kind == "op"
		and arg.op == "^"
		and arg.right.kind == "num"
		and arg.right.value == "2"
	then
		local base = arg.left
		if base.kind == "var" then
			if Assume.is(base, "positive") then
				return base
			elseif Assume.is(base, "negative") then
				return Node.Op("*", Node.Num("-1"), base)
			else
				return Node.Func("abs", { base })
			end
		end
	end

	-------------------------------------------------------
	-- Log Identities
	-------------------------------------------------------

	-- log10(1) -> 0
	if name == "log10" and isOne(arg) then
		return Node.Num("0")
	end

	if name == "log" then
		local base = arg2
		local val  = arg

		-- log(a, x) with missing args -> leave unchanged
		if not base or not val then
			return Node.Func("log", newArgs)
		end

		-- log(a, 1) = 0
		if isOne(val) then
			return Node.Num("0")
		end

		-- log(a, a) = 1
		if isNumeric(base) and isNumeric(val)
			and base.value == val.value then
			return Node.Num("1")
		end

		-- log(e, x) = ln(x)
		if base.kind == "const" and base.name == "e" then
			return Node.Func("ln", { val })
		end

		-- log(a, exp(x)) = x / ln(a)
		if val.kind == "func" and val.name == "exp" then
			return Node.Op("/",
				val.args[1],
				Node.Func("ln", { base })
			)
		end

		-- log(a, x^k) = k * log(a, x)
		if val.kind == "op" and val.op == "^"
			and val.right.kind == "num" then
			return Node.Op("*",
				val.right,
				Node.Func("log", { base, val.left })
			)
		end

		-- No rule matched -> return rebuilt node
		return Node.Func("log", newArgs)
	end

	-------------------------------------------------------
	-- Miscellaneous Identities
	-------------------------------------------------------

	-- abs(0) -> 0
	if name == "abs" and isZero(arg) then
		return Node.Num(0)
	end

	-- abs(x) -> x or -x
	if name == "abs" then
		if arg.kind == "var" then
			if Assume.is(arg, "positive") then
				return arg
			elseif Assume.is(arg, "negative") then
				return Node.Op("*", Node.Num("-1"), arg)
			end
		end
	end

	-- abs(-x) -> abs(x)
	if name == "abs"
		and arg.kind == "op"
		and arg.op == "*"
		and isNegOne(arg.left)
	then
		return Node.Func("abs", { arg.right })
	end

	-- floor(n) -> n for integers
	if name == "floor" and isNumeric(arg) and math.floor(tonumber(arg.value)) == tonumber(arg.value) then
		return arg
	end

	-- ceil(n) -> n for integers
	if name == "ceil" and isNumeric(arg) and math.ceil(tonumber(arg.value)) == tonumber(arg.value) then
		return arg
	end

	-------------------------------------------------------
	-- Other Identities
	-------------------------------------------------------

	-- sin(asin(x)) -> x
	if name == "sin"
		and arg.kind == "func"
		and arg.name == "asin" then
		return arg
	end

	-- cos(acos(x)) -> x
	if name == "cos"
		and arg.kind == "func"
		and arg.name == "acos" then
		return arg
	end

	-- tan(atan(x)) -> x
	if name == "tan"
		and arg.kind == "func"
		and arg.name == "atan" then
		return arg
	end

	-- abs(abs(x)) -> abs(x)
	if name == "abs"
		and arg.kind == "func"
		and arg.name == "abs" then
		return arg
	end

	-------------------------------------------------------
	-- Factorial
	-------------------------------------------------------

	if node.name == "factorial" then
		return simplifyFactorial(node)
	end
	
	-------------------------------------------------------
	-- Boolean NOT
	-------------------------------------------------------
	if name == "not" then
		-- not true -> false
		if isTrue(arg) then
			return Node.Const("false")
		end

		-- not false -> true
		if isFalse(arg) then
			return Node.Const("true")
		end

		-- not (not x) -> x
		if arg.kind == "func" and arg.name == "not" then
			return arg.args[1]
		end

		-- not(<comparison>) -> inverted comparison
		if arg.kind == "op" then
			local op = arg.op
			local L = arg.left
			local R = arg.right

			if op == "<"  then return Node.Op(">=", L, R) end
			if op == "<=" then return Node.Op(">",  L, R) end
			if op == ">"  then return Node.Op("<=", L, R) end
			if op == ">=" then return Node.Op("<",  L, R) end
			if op == "==" then return Node.Op("!=", L, R) end
			if op == "!=" then return Node.Op("==", L, R) end
		end

		-- no rule matched: rebuild if args changed
		if arg ~= node.args[1] then
			return Node.Func("not", { arg })
		else
			return node
		end
	end

	-------------------------------------------------------
	-- No function-specific rule applied
	-------------------------------------------------------

	-- Check if any argument changed
	local changed = false
	for i = 1, #args do
		if args[i] ~= newArgs[i] then
			changed = true
			break
		end
	end

	-- If arguments changed, rebuild the function node
	if changed then
		return Node.Func(name, newArgs)
	else
		return node
	end
end

-- Simplifies the operator node.
function Simplify._simplifyOp(node)
	local left = Simplify.simplify(node.left)
	local right = Simplify.simplify(node.right)
	local op = node.op

	-------------------------------------------------------
	-- Piecewise Handling
	-------------------------------------------------------

	if left.kind == "piecewise" and right.kind ~= "piecewise" then
		local branches = {}
		for _, pair in ipairs(left.branches) do
			local cond = pair[1]
			local expr = pair[2]
			local newExpr = Simplify.simplify(Node.Op(op, expr, right))
			table_insert(branches, { cond, newExpr })
		end
		return Node.Piecewise(branches)
	end
	
	if right.kind == "piecewise" and left.kind ~= "piecewise" then
		local branches = {}
		for _, pair in ipairs(right.branches) do
			local cond = pair[1]
			local expr = pair[2]
			local newExpr = Simplify.simplify(Node.Op(op, expr, right))
			table_insert(branches, { cond, newExpr })
		end
		return Node.Piecewise(branches)
	end

	-------------------------------------------------------
	-- Constant folding
	-------------------------------------------------------
	if isNumeric(left) and isNumeric(right) then
		return Simplify._foldConstants(op, left, right)
	end

	-------------------------------------------------------
	-- Algebraic identities and structural simplifications
	-------------------------------------------------------

	-------------------------------------------------------
	-- ADDITION
	-------------------------------------------------------
	if op == "+" then
		-- x + 0 -> x
		if isZero(right) then return left end
		if isZero(left) then return right end

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
			and isNumeric(left.left)
			and isNumeric(left.right)
			and isNumeric(right) then

			local sum = tonumber(left.left.value)
				+ tonumber(left.right.value)
				+ tonumber(right.value)

			return Node.Num(tostring(sum))
		end

		-- (x + a) + b -> x + (a+b)
		if left.kind == "op" and left.op == "+"
			and isNumeric(left.right)
			and isNumeric(right) then

			local sum = tonumber(left.right.value) + tonumber(right.value)
			return Node.Op("+", left.left, Node.Num(tostring(sum)))
		end

		-- sin(x)^2 + cos(x)^2 -> 1

		-- checks if node == sin(x)^2
		local function isSin2(node)
			return node.kind == "op"
				and node.op == "^"
				and node.left.kind == "func"
				and node.left.name == "sin"
				and node.right.kind == "num"
				and node.right.value == "2"
		end

		-- checks if node == cos(x)^2
		local function isCos2(node)
			return node.kind == "op"
				and node.op == "^"
				and node.left.kind == "func"
				and node.left.name == "cos"
				and node.right.kind == "num"
				and node.right.value == "2"
		end

		-- Check for sin(x)^2 + cos(x)^2 in either order
		if isSin2(left) and isCos2(right) then
			-- same argument?
			if Util.nodeEquals(left.left.args[1], right.left.args[1]) then
				return Node.Num("1")
			end
		end

		if isCos2(left) and isSin2(right) then
			if Util.nodeEquals(left.left.args[1], right.left.args[1]) then
				return Node.Num("1")
			end
		end

		-- x + (-1)*y -> x - y
		if right.kind == "op" and right.op == "*"
			and isNegOne(right.left) then

			return Node.Op("-", left, right.right)
		end

		-- (-1)*x + y -> y - x
		if left.kind == "op" and left.op == "*"
			and isNegOne(left.left) then
			return Node.Op("-", right, left.right)
		end

		-- x + -(y) -> x - y
		if right.kind == "op" and right.op == "*"
			and isNegOne(right.left) then
			return Node.Op("-", left, right.right)
		end

		-- (a + bi) + (c + di)
		if left.kind == "complex" and right.kind == "complex" then
			return Node.Complex(
				Node.Op("+", left.real, right.real),
				Node.Op("+", left.imag, right.imag)
			)
		end
	end

	-------------------------------------------------------
	-- SUBTRACTION
	-------------------------------------------------------
	if op == "-" then
		-- x - 0 -> x
		if isZero(right) then
			return left
		end

		-- 0 - x -> -x
		if isZero(left) then
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
		if isOne(right) then return left end
		if isOne(left) then return right end

		-- x * 0 -> 0
		if isZero(right) then return right end
		if isZero(left) then return left end

		-- (-1) * (-1) -> 1
		if isNegOne(left)
			and isNegOne(right) then
			return Node.Num("1")
		end

		-- (-1) * n -> -n
		if isNegOne(left)
			and isNumeric(right) then
			return Node.Num(tostring(-tonumber(right.value)))
		end

		-- x * (-1) -> -x
		if isNegOne(right) then
			return Node.Op("*", Node.Num("-1"), left)
		end

		-- -1 * x -> -x
		if isNegOne(left) then
			return Node.Op("*", Node.Num("-1"), right)
		end

		-- -(-x) -> x
		if isNegOne(left)
			and right.kind == "op" and right.op == "*"
			and isNegOne(right.left) then
			return right.right
		end

		-- (-1) * (u / v) -> -(u / v)
		if isNegOne(left)
			and right.kind == "op" and right.op == "/" then
			return Node.Op("*", Node.Num("-1"), right)
		end

		-- (u / v) * (-1) -> -(u / v)
		if isNegOne(right)
			and left.kind == "op" and left.op == "/" then
			return Node.Op("*", Node.Num("-1"), left)
		end

		-- (-1) * (u * v) -> -(u * v)
		if isNegOne(left)
			and right.kind == "op" and right.op == "*" then
			return Node.Op("*", Node.Num("-1"), right)
		end

		-- (u * v) * (-1) -> -(u * v)
		if isNegOne(right)
			and left.kind == "op" and left.op == "*" then
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
			and isNumeric(left.left)
			and isNumeric(left.right)
			and isNumeric(right) then

			local prod = tonumber(left.left.value)
				* tonumber(left.right.value)
				* tonumber(right.value)

			return Node.Num(tostring(prod))
		end

		-- (x * a) * b -> x * (a*b)
		if left.kind == "op" and left.op == "*"
			and isNumeric(left.right)
			and isNumeric(right) then

			local prod = tonumber(left.right.value) * tonumber(right.value)
			return Node.Op("*", left.left, Node.Num(tostring(prod)))
		end

		-- 1/x * x -> 1 (reverse order)
		if left.kind == "op" and left.op == "/"
			and isOne(left.left)
			and Util.nodeEquals(left.right, right) then
			return Node.Num("1")
		end

		-- Negation propagation: (-1)*(u+v) -> (-u) + (-v)
		if isNegOne(left)
			and right.kind == "op" and right.op == "+" then

			local negLeft = Node.Op("*", Node.Num("-1"), right.left)
			local negRight = Node.Op("*", Node.Num("-1"), right.right)

			return Node.Op("+",
				Simplify.simplify(negLeft),
				Simplify.simplify(negRight)
			)
		end

		-- x * i
		if right.kind == "const" and right.name == "i" then
			return Node.Complex(Node.Num("0"), left)
		end

		-- i * x
		if left.kind == "const" and left.name == "i" then
			return Node.Complex(Node.Num("0"), right)
		end

		if left.kind == "const" and left.name == "i"
			and right.kind == "const" and right.name == "i" then
			return Node.Num("-1")
		end

		-- (a + bi) * (c + di)
		if left.kind == "complex" and right.kind == "complex" then
			local ac = Node.Op("*", left.real, right.real)
			local bd = Node.Op("*", left.imag, right.imag)
			local ad = Node.Op("*", left.real, right.imag)
			local bc = Node.Op("*", left.imag, right.real)

			return Node.Complex(
				Node.Op("-", ac, bd),
				Node.Op("+", ad, bc)
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

		-- x / x -> x if x ~= 0
		if Util.nodeEquals(left, right) then
			if left.kind == "var" and Assume.is(left, "nonzero") then
				return Node.Num("1")
			end
		end

		-- (u * 1) / v -> u / v
		if left.kind == "op" and left.op == "*" then
			if isOne(left.right)then
				return Node.Op("/", left.left, right)
			end
			if isOne(left.left) then
				return Node.Op("/", left.right, right)
			end
		end

		-- (u * -1) / v -> -(u / v)
		if left.kind == "op" and left.op == "*"
			and isNegOne(left.right) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", left.left, right))
		end

		-- -(u) / v -> -(u / v)
		if left.kind == "op" and left.op == "*"
			and isNegOne(left.left) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", left.right, right))
		end

		-- u / -(v) -> -(u / v)
		if right.kind == "op" and right.op == "*"
			and isNegOne(right.left) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", left, right.right))
		end

		-- x / -y = -(x / y)
		if isNegOne(right) then
			return Node.Op("*", Node.Num("-1"), Node.Op("/", left, Node.Num("1")))
		end

		-------------------------------------------------------
		-- Reciprocal trig collapsing
		-------------------------------------------------------

		-- 1 / cos(x) -> sec(x)
		if isOne(left)
			and right.kind == "func" and right.name == "cos" then
			return Node.Func("sec", {right.args[1]})
		end

		-- 1 / sin(x) -> csc(x)
		if isOne(left)
			and right.kind == "func" and right.name == "sin" then
			return Node.Func("csc", {right.args[1]})
		end

		-- cos(x) / sin(x) -> cot(x)
		if left.kind == "func" and left.name == "cos"
			and right.kind == "func" and right.name == "sin" then
			return Node.Func("cot", {left.args[1]})
		end

		-------------------------------------------------------
		-- Hyperbolic versions
		-------------------------------------------------------

		-- 1 / cosh(x) -> sech(x)
		if isOne(left)
			and right.kind == "func" and right.name == "cosh" then
			return Node.Func("sech", {right.args[1]})
		end

		-- 1 / sinh(x) -> csch(x)
		if isOne(left)
			and right.kind == "func" and right.name == "sinh" then
			return Node.Func("csch", {right.args[1]})
		end

		-- cosh(x) / sinh(x) -> coth(x)
		if left.kind == "func" and left.name == "cosh"
			and right.kind == "func" and right.name == "sinh" then
			return Node.Func("coth", {left.args[1]})
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
		if isOne(right) then
			return left
		end

		-- x^0 -> 1
		if isZero(right) then
			return Node.Num("1")
		end

		-- x^(-1) -> 1/x
		if isNegOne(right) then
			return Node.Op("/", Node.Num("1"), left)
		end

		-- (x^a)^b -> x^(a*b)
		if left.kind == "op" and left.op == "^"
			and isNumeric(right)
			and isNumeric(left.right) then

			local newExp = tonumber(left.right.value) * tonumber(right.value)
			return Node.Op("^", left.left, Node.Num(tostring(newExp)))
		end
	end
	
	-------------------------------------------------------
	-- Boolean AND
	-------------------------------------------------------
	if op == "and" then
		-- true and x -> x
		if isTrue(left) then
			return right
		end

		-- false and x -> false
		if isFalse(left) then
			return Node.Const("false")
		end

		-- x and true -> x
		if isTrue(right) then
			return left
		end

		-- x and false -> false
		if isFalse(right) then
			return Node.Const("false")
		end

		-- no rule matched: rebuild if changed
		if left == node.left and right == node.right then
			return node
		end
		return Node.Op("and", left, right)
	end

	-------------------------------------------------------
	-- Boolean OR
	-------------------------------------------------------
	if op == "or" then
		-- true or x -> true
		if isTrue(left) then
			return Node.Const("true")
		end

		-- false or x -> x
		if isFalse(left) then
			return right
		end

		-- x or true -> true
		if isTrue(right) then
			return Node.Const("true")
		end

		-- x or false -> x
		if isFalse(right) then
			return left
		end

		-- no rule matched: rebuild if changed
		if left == node.left and right == node.right then
			return node
		end
		return Node.Op("or", left, right)
	end

	-------------------------------------------------------
	-- No simplification applied -> rebuild if needed
	-------------------------------------------------------
	if left == node.left and right == node.right then
		return node
	end

	return Node.Op(op, left, right)
end

-- Simplifies the complex number
function Simplify._simplifyComplex(node)
	local real = Simplify.simplify(node.real)
	local imag = Simplify.simplify(node.imag)

	-- 0 + 0i -> 0
	if real.kind == "num" and real.value == "0"
		and imag.kind == "num" and imag.value == "0" then
		return Node.Num("0")
	end

	-- a + 0i -> a
	if imag.kind == "num" and imag.value == "0" then
		return real
	end

	-- 0 + bi -> b*i
	if real.kind == "num" and real.value == "0" then
		return Node.Op("*", imag, Node.Const("i"))
	end

	-- Otherwise keep as complex node
	return Node.Complex(real, imag)
end

--[[
    Constant folding helper.

    Given an operator and two *numeric nodes* (Num or Rat),
    evaluate the operation exactly in the rational domain.

    Behavior:
      - Converts both operands into rational form (n/d).
      - Performs exact arithmetic:
            +  -> (a/b) + (c/d)
            -  -> (a/b) - (c/d)
            *  -> (a/b) * (c/d)
            /  -> (a/b) / (c/d)
            ^  -> (a/b)^k   (only when exponent is an integer literal)
      - Returns a new Rat node (which Node.Rat will reduce via gcd).
      - If either operand is non-numeric, falls back to building an Op node.

    Notes:
      - This function now operates on *nodes*, not raw strings.
      - Canonicalization (e.g., Rat(n,1) -> Num(n)) is handled by Canon.canonical.
]]
function Simplify._foldConstants(op, a, b)
	-- Convert both operands to rational form
	local na, da = toRat(a)
	local nb, db = toRat(b)

	-- If either is not numeric, fallback
	if not na or not nb then
		return Node.Op(op, a, b)
	end

	if op == "+" then
		return Node.Rat(na*db + nb*da, da*db)
	end

	if op == "-" then
		return Node.Rat(na*db - nb*da, da*db)
	end

	if op == "*" then
		return Node.Rat(na*nb, da*db)
	end

	if op == "/" then
		return Node.Rat(na*db, da*nb)
	end

	if op == "^" then
		-- Only allow rational ^ integer
		if b.kind == "num" then
			local k = tonumber(b.value)
			return Node.Rat(na^k, da^k)
		end
	end

	-- Fallback
	return Node.Op(op, a, b)
end

-- Simplifies piecewise.
function Simplify._simplifyPiecewise(node)
	local newBranches = {}

	for _, pair in ipairs(node.branches) do
		local cond = Simplify.simplify(pair[1])
		local expr = Simplify.simplify(pair[2])
		table_insert(newBranches, { cond, expr })
	end

	return Node.Piecewise(newBranches)
end

-- The Simplifier sub-library.
return Simplify