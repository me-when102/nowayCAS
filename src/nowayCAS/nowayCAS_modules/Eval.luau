local Eval = {}

local tonumber = tonumber

-------------------------------------------------------
-- Evaluator
-- Evaluates an AST numerically given an environment.
-- env is a table mapping variable names to numbers.
-- Example: Eval.eval(ast, { x = 3 })
-------------------------------------------------------

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

		if f == "sin" then return math.sin(arg) end
		if f == "cos" then return math.cos(arg) end
		if f == "exp" then return math.exp(arg) end
		if f == "ln"  then return math.log(arg) end
		if f == "sqrt" then return math.sqrt(arg) end

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