local Eval = {}

local tonumber = tonumber

local UserFunctions = require(script.Parent.UserFunctions)
local UserConstants = require(script.Parent.UserConstants)
local Substitute = require(script.Parent.Substitute)
local Complex = require(script.Parent.Complex)
local Util = require(script.Parent.Util)

-------------------------------------------------------
-- Evaluator
-- Evaluates an AST numerically given an environment.
-- env is a table mapping variable names to numbers.
-- Example: Eval.eval(ast, { x = 3 })
-------------------------------------------------------

local BUILTIN_CONST = {
	pi = math.pi,
	phi = (1 + math.sqrt(5)) / 2,
	tau = 2 * math.pi
}

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
		-- Numbers
		-------------------------------------------------------

	elseif kind == "rat" then

		return node.num / node.den

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
		-- Constants
		-------------------------------------------------------
	elseif kind == "const" then
		-- built-in constants
		local v = BUILTIN_CONST[node.name]
		if v ~= nil then return v end

		-- user-defined constants
		local u = UserConstants.lookup(node.name)
		if u ~= nil then return u end

		error("nowayCAS.Eval: unknown constant '" .. node.name .. "'")

		-------------------------------------------------------
		-- Piecewise
		-------------------------------------------------------
	elseif kind == "piecewise" then
		for _, pair in ipairs(node.branches) do
			local condNode = pair[1]
			local exprNode = pair[2]

			-- Evaluate condition
			local condVal = Eval.eval(condNode, env)

			if condVal then
				return Eval.eval(exprNode, env)
			end
		end

		error("nowayCAS.Eval: no branch condition evaluated to true")

		-------------------------------------------------------
		-- Functions
		-------------------------------------------------------
	elseif kind == "func" then
		local f = node.name

		-------------------------------------------------------
		-- User defined function?
		-------------------------------------------------------
		local def = UserFunctions.lookup(f)
		if def then
			-- Build substitution environment directly
			local subEnv = {}
			for i, param in ipairs(def.params) do
				subEnv[param] = node.args[i]
			end

			-- Substitute + evaluate
			return Eval.eval(Substitute.apply(def.body, subEnv), env)
		end

		-------------------------------------------------------
		-- Built-in Functions (single argument)
		-------------------------------------------------------
		-- Evaluate all args (even though built-ins only use the first)
		local args = {}
		for i, a in ipairs(node.args) do
			args[i] = Eval.eval(a, env)
		end

		-- get arguments
		local arg = args[1]
		local arg2 = args[2]

		-- allow complex for sqrt only
		if f ~= "sqrt" and Complex.is(arg) then
			error("nowayCAS.Eval: function '" .. f .. "' expected real argument")
		end

		-- Basic trig
		if f == "sin"  then return math.sin(arg) end
		if f == "cos"  then return math.cos(arg) end
		if f == "tan"  then return math.tan(arg) end

		-- Reciprocal trig
		if f == "sec"  then return 1 / math.cos(arg) end
		if f == "csc"  then return 1 / math.sin(arg) end
		if f == "cot"  then return math.cos(arg) / math.sin(arg) end

		-- Inverse trig
		if f == "asin" then return math.asin(arg) end
		if f == "acos" then return math.acos(arg) end
		if f == "atan" then return math.atan(arg) end

		-- Inverse reciprocal trig
		if f == "asec" then return math.acos(1 / arg) end
		if f == "acsc" then return math.asin(1 / arg) end
		if f == "acot" then return math.atan(1 / arg) end

		-- Hyperbolic
		if f == "sinh" then return math.sinh(arg) end
		if f == "cosh" then return math.cosh(arg) end
		if f == "tanh" then return math.tanh(arg) end

		-- Reciprocal hyperbolic
		if f == "sech" then return 1 / math.cosh(arg) end
		if f == "csch" then return 1 / math.sinh(arg) end
		if f == "coth" then return math.cosh(arg) / math.sinh(arg) end

		-- Inverse hyperbolic
		if f == "asinh" then return asinh(arg) end
		if f == "acosh" then return acosh(arg) end
		if f == "atanh" then return atanh(arg) end

		-- Inverse reciprocal hyperbolic
		if f == "asech" then return acosh(1 / arg) end
		if f == "acsch" then return asinh(1 / arg) end
		if f == "acoth" then return atanh(1 / arg) end

		-- Exponential / log
		if f == "exp"  then return math.exp(arg) end
		if f == "ln"   then return math.log(arg) end

		-- Misc
		if f == "sqrt" then return Complex.sqrt(arg) end
		if f == "abs"  then return math.abs(arg) end
		if f == "floor" then return math.floor(arg) end
		if f == "ceil"  then return math.ceil(arg) end
		if f == "sign" then return math.sign(arg) end

		-- Log
		if f == "log10" then return math.log10(arg) end
		if f == "log" then return math.log(arg, arg2) end
		
		-- Factorial
		if f == "factorial" then return Util.factorial(arg) end
		
		error("nowayCAS.Eval: unsupported function '" .. f .. "'")

		-------------------------------------------------------
		-- Operators
		-------------------------------------------------------
	elseif kind == "op" then
		local op = node.op
		local left = Eval.eval(node.left, env)
		local right = Eval.eval(node.right, env)

		if op == "+" then
			if Complex.is(left) or Complex.is(right) then
				return Complex.add(left, right)
			end
			return left + right
		end

		if op == "-" then
			if Complex.is(left) or Complex.is(right) then
				return Complex.sub(left, right)
			end
			return left - right
		end

		if op == "*" then
			if Complex.is(left) or Complex.is(right) then
				return Complex.mul(left, right)
			end
			return left * right
		end

		if op == "/" then
			if Complex.is(left) or Complex.is(right) then
				return Complex.div(left, right)
			end
			return left / right
		end

		if op == "^" then
			if Complex.is(left) or Complex.is(right) then
				return Complex.pow(left, right)
			end
			return left ^ right
		end

		error("nowayCAS.Eval: unsupported operator '" .. op .. "'")
	end

	error("nowayCAS.Eval: unknown node kind '" .. tostring(kind) .. "'")
end

-- The Evaluator sub-library
return Eval