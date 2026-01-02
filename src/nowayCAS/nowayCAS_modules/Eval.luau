local Eval = {}

local tonumber = tonumber

-------------------------------------------------------
-- Evaluator
-- Evaluates an AST numerically given an environment.
-- env is a table mapping variable names to numbers.
-- Example: Eval.eval(ast, { x = 3 })
-------------------------------------------------------

-- manual inverse hyperbolic functions
local function asinh(x)
	return math.log(x + math.sqrt(x*x + 1))
end

local function acosh(x)
	return math.log(x + math.sqrt(x - 1) * math.sqrt(x + 1))
end

local function atanh(x)
	return 0.5 * math.log((1 + x) / (1 - x))
end

-- Evaluate a node
function Eval.eval(node, env)
	local kind = node.kind

	-------------------------------------------------------
	-- Numbers
	-------------------------------------------------------
	if kind == "num" then
		return tonumber(node.value)

		-------------------------------------------------------
		-- Variables
		-------------------------------------------------------
	elseif kind == "var" then
		local v = env[node.name]
		if v == nil then
			error("nowayCAS.Eval: variable '" .. node.name .. "' not provided")
		end
		return v

		-------------------------------------------------------
		-- Functions
		-------------------------------------------------------
	elseif kind == "func" then
		local arg = Eval.eval(node.arg, env)

		local f = node.name
		
		-- guard: make sure arg is a number.
		if type(arg) ~= "number" then
			error("nowayCAS.Eval: function '" .. f .. "' expected numeric argument")
		end

		-- Basic trig
		if f == "sin"  then return math.sin(arg) end
		if f == "cos"  then return math.cos(arg) end
		if f == "tan"  then return math.tan(arg) end

		-- Inverse trig
		if f == "asin" then return math.asin(arg) end
		if f == "acos" then return math.acos(arg) end
		if f == "atan" then return math.atan(arg) end

		-- Hyperbolic
		if f == "sinh" then return math.sinh(arg) end
		if f == "cosh" then return math.cosh(arg) end
		if f == "tanh" then return math.tanh(arg) end

		-- Inverse hyperbolic
		if f == "asinh" then return asinh(arg) end
		if f == "acosh" then return acosh(arg) end
		if f == "atanh" then return atanh(arg) end

		-- Exponential / log
		if f == "exp"  then return math.exp(arg) end
		if f == "ln"   then return math.log(arg) end

		-- Misc
		if f == "sqrt" then return math.sqrt(arg) end
		if f == "abs"  then return math.abs(arg) end
		if f == "floor" then return math.floor(arg) end
		if f == "ceil"  then return math.ceil(arg) end

		error("nowayCAS.Eval: unsupported function '" .. f .. "'")

		-------------------------------------------------------
		-- Operators
		-------------------------------------------------------
	elseif kind == "op" then
		local op = node.op
		local left = Eval.eval(node.left, env)
		local right = Eval.eval(node.right, env)

		if op == "+" then return left + right end
		if op == "-" then return left - right end
		if op == "*" then return left * right end
		if op == "/" then return left / right end
		if op == "^" then return left ^ right end

		error("nowayCAS.Eval: unsupported operator '" .. op .. "'")
	end

	error("nowayCAS.Eval: unknown node kind '" .. tostring(kind) .. "'")
end

-- The Evaluator sub-library
return Eval