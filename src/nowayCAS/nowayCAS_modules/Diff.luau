local Diff = {}
local DIFF_CACHE = {}

local Node = require(script.Parent.Node)

local tostring = tostring
local tonumber = tonumber

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

	-------------------------------------------------------
	-- Trigonometric
	-------------------------------------------------------

	-- d/dx sin(u) = cos(u) * u'
	if f == "sin" then
		return Node.Op("*", Node.Func("cos", u), du)

		-- d/dx cos(u) = -sin(u) * u'
	elseif f == "cos" then
		return Node.Op("*",
			Node.Op("*", Node.Num("-1"), Node.Func("sin", u)),
			du
		)

		-- d/dx tan(u) = sec(u)^2 * u'
	elseif f == "tan" then
		return Node.Op("*",
			Node.Op("^", Node.Func("sec", u), Node.Num("2")),
			du
		)
	end
	
	-------------------------------------------------------
	-- Reciprocal Trigonometric
	-------------------------------------------------------
	
	-- d/dx sec(u) = sec(u) * tan(u) * u'
	if f == "sec" then
		return Node.Op("*",
			Node.Op("*", Node.Func("sec", u), Node.Func("tan", u)),
			du
		)

		-- d/dx csc(u) = -csc(u) * cot(u) * u'
	elseif f == "csc" then
		return Node.Op("*",
			Node.Num("-1"),
			Node.Op("*",
				Node.Func("csc", u),
				Node.Op("*", Node.Func("cot", u), du)
			)
		)

		-- d/dx cot(u) = -csc(u)^2 * u'
	elseif f == "cot" then
		return Node.Op("*",
			Node.Num("-1"),
			Node.Op("*",
				Node.Op("^", Node.Func("csc", u), Node.Num("2")),
				du
			)
		)
	end
	
	-------------------------------------------------------
	-- Inverse Trigonometric
	-------------------------------------------------------

	-- d/dx asin(u) = u' / sqrt(1 - u^2)
	if f == "asin" then
		return Node.Op("/",
			du,
			Node.Func("sqrt",
				Node.Op("-", Node.Num("1"),
					Node.Op("^", u, Node.Num("2"))
				)
			)
		)

		-- d/dx acos(u) = -u' / sqrt(1 - u^2)
	elseif f == "acos" then
		return Node.Op("*",
			Node.Num("-1"),
			Diff._diffFunc(Node.Func("asin", u), var)
		)

		-- d/dx atan(u) = u' / (1 + u^2)
	elseif f == "atan" then
		return Node.Op("/",
			du,
			Node.Op("+", Node.Num("1"),
				Node.Op("^", u, Node.Num("2"))
			)
		)
	end
	
	-------------------------------------------------------
	-- Reciprocal Inverse Trigonometric
	-------------------------------------------------------
	
	-- d/dx asec(u) = u' / (|u| * sqrt(u^2 - 1))
	if f == "asec" then
		return Node.Op("/",
			du,
			Node.Op("*",
				Node.Func("abs", u),
				Node.Func("sqrt",
					Node.Op("-", Node.Op("^", u, Node.Num("2")), Node.Num("1"))
				)
			)
		)

		-- d/dx acsc(u) = -u' / (|u| * sqrt(u^2 - 1))
	elseif f == "acsc" then
		return Node.Op("*",
			Node.Num("-1"),
			Diff._diffFunc(Node.Func("asec", u), var)
		)

		-- d/dx acot(u) = -u' / (1 + u^2)
	elseif f == "acot" then
		return Node.Op("*",
			Node.Num("-1"),
			Node.Op("/",
				du,
				Node.Op("+", Node.Num("1"),
					Node.Op("^", u, Node.Num("2"))
				)
			)
		)
	end

	-------------------------------------------------------
	-- Hyperbolic
	-------------------------------------------------------

	-- d/dx sinh(u) = cosh(u) * u'
	if f == "sinh" then
		return Node.Op("*", Node.Func("cosh", u), du)

		-- d/dx cosh(u) = sinh(u) * u'
	elseif f == "cosh" then
		return Node.Op("*", Node.Func("sinh", u), du)

		-- d/dx tanh(u) = (1 - tanh(u)^2) * u'
	elseif f == "tanh" then
		return Node.Op("*",
			Node.Op("-", Node.Num("1"),
				Node.Op("^", Node.Func("tanh", u), Node.Num("2"))
			),
			du
		)
	end
	
	-------------------------------------------------------
	-- Reciprocal Hyperbolic
	-------------------------------------------------------
	
	-- d/dx sech(u) = -sech(u) * tanh(u) * u'
	if f == "sech" then
		return Node.Op("*",
			Node.Num("-1"),
			Node.Op("*",
				Node.Func("sech", u),
				Node.Op("*", Node.Func("tanh", u), du)
			)
		)

		-- d/dx csch(u) = -csch(u) * coth(u) * u'
	elseif f == "csch" then
		return Node.Op("*",
			Node.Num("-1"),
			Node.Op("*",
				Node.Func("csch", u),
				Node.Op("*", Node.Func("coth", u), du)
			)
		)

		-- d/dx coth(u) = -csch(u)^2 * u'
	elseif f == "coth" then
		return Node.Op("*",
			Node.Num("-1"),
			Node.Op("*",
				Node.Op("^", Node.Func("csch", u), Node.Num("2")),
				du
			)
		)
	end
	
	-------------------------------------------------------
	-- Inverse Hyperbolic
	-------------------------------------------------------

	-- d/dx asinh(u) = u' / sqrt(1 + u^2)
	if f == "asinh" then
		return Node.Op("/",
			du,
			Node.Func("sqrt",
				Node.Op("+", Node.Num("1"),
					Node.Op("^", u, Node.Num("2"))
				)
			)
		)

		-- d/dx acosh(u) = u' / (sqrt(u - 1) * sqrt(u + 1))
	elseif f == "acosh" then
		return Node.Op("/",
			du,
			Node.Op("*",
				Node.Func("sqrt", Node.Op("-", u, Node.Num("1"))),
				Node.Func("sqrt", Node.Op("+", u, Node.Num("1")))
			)
		)

		-- d/dx atanh(u) = u' / (1 - u^2)
	elseif f == "atanh" then
		return Node.Op("/",
			du,
			Node.Op("-", Node.Num("1"),
				Node.Op("^", u, Node.Num("2"))
			)
		)
	end
	
	-------------------------------------------------------
	-- Inverse Reciprocal Hyperbolic
	-------------------------------------------------------
	
	-- d/dx asech(u) = -u' / (u * sqrt(1 - u^2))
	if f == "asech" then
		return Node.Op("*",
			Node.Num("-1"),
			Node.Op("/",
				du,
				Node.Op("*",
					u,
					Node.Func("sqrt",
						Node.Op("-", Node.Num("1"),
							Node.Op("^", u, Node.Num("2"))
						)
					)
				)
			)
		)

		-- d/dx acsch(u) = -u' / (|u| * sqrt(1 + u^2))
	elseif f == "acsch" then
		return Node.Op("*",
			Node.Num("-1"),
			Node.Op("/",
				du,
				Node.Op("*",
					Node.Func("abs", u),
					Node.Func("sqrt",
						Node.Op("+", Node.Num("1"),
							Node.Op("^", u, Node.Num("2"))
						)
					)
				)
			)
		)

		-- d/dx acoth(u) = u' / (1 - u^2)
	elseif f == "acoth" then
		return Node.Op("/",
			du,
			Node.Op("-", Node.Num("1"),
				Node.Op("^", u, Node.Num("2"))
			)
		)
	end

	-------------------------------------------------------
	-- Exponential / Logarithmic
	-------------------------------------------------------

	-- d/dx exp(u) = exp(u) * u'
	if f == "exp" then
		return Node.Op("*", Node.Func("exp", u), du)

		-- d/dx ln(u) = u' / u
	elseif f == "ln" then
		return Node.Op("*",
			Node.Op("/", Node.Num("1"), u),
			du
		)
	end

	-------------------------------------------------------
	-- Square Root
	-------------------------------------------------------

	if f == "sqrt" then
		-- u' = 0 → derivative is 0
		if du.kind == "num" and du.value == "0" then
			return Node.Num("0")
		end

		-- d/dx sqrt(u) = u' / (2 * sqrt(u))
		return Node.Op("/",
			du,
			Node.Op("*",
				Node.Num("2"),
				Node.Func("sqrt", u)
			)
		)
	end

	-------------------------------------------------------
	-- Miscellaneous
	-------------------------------------------------------

	-- d/dx abs(u) = u' * sign(u)
	if f == "abs" then
		return Node.Op("*", Node.Func("sign", u), du)
	end

	-- d/dx floor(u) = 0 (almost everywhere)
	if f == "floor" then
		return Node.Num("0")
	end

	-- d/dx ceil(u) = 0 (almost everywhere)
	if f == "ceil" then
		return Node.Num("0")
	end

	-------------------------------------------------------
	-- Unsupported
	-------------------------------------------------------

	error("Diff: Unsupported function '" .. f .. "'")
end

-- The Differentiator sub-library.
return Diff