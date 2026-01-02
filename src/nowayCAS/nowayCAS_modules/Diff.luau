local Diff = {}
local DIFF_CACHE = {}

local Node = require(script.Parent.Node)

-------------------------------------------------------
-- Differentiation
-- Computes d/d(var) of an AST node.
-- Returns a new AST node (never mutates).
-------------------------------------------------------

-- Computes the dervative of a node with respect to a variable.
function Diff.diff(node, var)
	local key = node
	local cached = DIFF_CACHE[key]
	if cached then
		return cached
	end

	local result
	if node.kind == "num" then
		result = Node.Num("0")
	elseif node.kind == "var" then
		result = Node.Num(node.name == var and "1" or "0")
	elseif node.kind == "op" then
		result = Diff._diffOp(node, var)
	elseif node.kind == "func" then
		result = Diff._diffFunc(node, var)
	else
		error("Diff: Unknown node kind '" .. tostring(node.kind) .. "'")
	end

	DIFF_CACHE[key] = result
	return result
end


-- Differentiates an operator node using sum, product, quotient, and power rules.
function Diff._diffOp(node, var)
	local op = node.op
	local u = node.left
	local v = node.right

	local du = Diff.diff(u, var)
	local dv = Diff.diff(v, var)

	if op == "+" then
		return Node.Op("+", du, dv)

	elseif op == "-" then
		return Node.Op("-", du, dv)

	elseif op == "*" then
		-- Product rule: (uv)' = u'v + uv'
		return Node.Op("+",
			Node.Op("*", du, v),
			Node.Op("*", u, dv)
		)

	elseif op == "/" then
		-- Quotient rule: (u/v)' = (u'v - uv') / v^2
		return Node.Op("/",
			Node.Op("-",
				Node.Op("*", du, v),
				Node.Op("*", u, dv)
			),
			Node.Op("^", v, Node.Num("2"))
		)

	elseif op == "^" then
		if v.kind == "num" then
			local n = tonumber(v.value)
			if n == 0 then return Node.Num("0") end
			-- u^n -> n u^(n-1) u'
			return Node.Op("*",
				Node.Op("*", Node.Num(tostring(n)), Node.Op("^", u, Node.Num(tostring(n-1)))),
				du
			)
		end

		-- 2) General case: (u^v)' = u^v * (v' ln u + v u'/u)
		return Node.Op("*",
			Node.Op("^", u, v),
			Node.Op("+",
				Node.Op("*", dv, Node.Func("ln", u)),
				Node.Op("*", v,
					Node.Op("/", du, u)
				)
			)
		)
	end

	error("Diff: Unsupported operator '" .. op .. "'")
end

-- Differentiates a function node using the chain rule and built-in function derivatives.
function Diff._diffFunc(node, var)
	local f = node.name
	local u = node.arg
	local du = Diff.diff(u, var)

	if f == "sin" then
		return Node.Op("*", Node.Func("cos", u), du)

	elseif f == "cos" then
		return Node.Op("*",
			Node.Op("*", Node.Num("-1"), Node.Func("sin", u)),
			du
		)

	elseif f == "exp" then
		return Node.Op("*", Node.Func("exp", u), du)

	elseif f == "ln" then
		return Node.Op("*",
			Node.Op("/", Node.Num("1"), u),
			du
		)
	elseif f == "sqrt" then
		-- If u' = 0, derivative is 0
		if du.kind == "num" and du.value == "0" then
			return Node.Num("0")
		end

		-- Otherwise: (u') / (2 * sqrt(u))
		return Node.Op("/",
			du,
			Node.Op("*",
				Node.Num("2"),
				Node.Func("sqrt", u)
			)
		)
	end

	error("Diff: Unsupported function '" .. f .. "'")
end

-- The Differentiator sub-library.
return Diff