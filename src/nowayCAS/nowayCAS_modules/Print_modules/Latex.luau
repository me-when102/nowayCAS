local Latex = {}

local PrintHelpers = require(script.Parent.PrintHelpers)

local table_insert = table.insert

-------------------------------------------------------
-- LaTeX Printer
-------------------------------------------------------

local latexNames = {
	-- Elementary
	ln    = "ln",
	sqrt  = "sqrt",
	abs   = "abs",

	-- Trigonometric
	sin   = "sin",
	cos   = "cos",
	tan   = "tan",
	csc   = "csc",
	sec   = "sec",
	cot   = "cot",

	-- Inverse trigonometric
	asin  = "arcsin",
	acos  = "arccos",
	atan  = "arctan",
	acsc  = "operatorname{arccsc}",
	asec  = "operatorname{arcsec}",
	acot  = "operatorname{arccot}",

	-- Hyperbolic
	sinh  = "sinh",
	cosh  = "cosh",
	tanh  = "tanh",
	csch  = "csch",
	sech  = "sech",
	coth  = "coth",

	-- Inverse hyperbolic
	asinh = "operatorname{asinh}",
	acosh = "operatorname{acosh}",
	atanh = "operatorname{atanh}",
	acsch = "operatorname{acsch}",
	asech = "operatorname{asech}",
	acoth = "operatorname{acoth}",
}

local cmpLatex = {
	["<"]  = "<",
	[">"]  = ">",
	["<="] = "\\le",
	[">="] = "\\ge",
	["=="] = "=",
	["!="] = "\\neq",
}

-- Get precedence of the node for LaTeX.
local function latexPrec(node)
	if node.kind ~= "op" then
		return 10
	end
	return PrintHelpers.PRECEDENCE[node.op] or 10
end

-- Wrap parenthesis / brackets determined by precedence for LaTeX.
local function latexParen(child, parentOp, isRight)
	if child.kind ~= "op" then
		return Latex._toLatex(child)
	end

	local c = latexPrec(child)
	local p = PrintHelpers.PRECEDENCE[parentOp] or 0

	-- Lower precedence -> must wrap
	if c < p then
		return "(" .. Latex._toLatex(child) .. ")"
	end

	-- Right-associativity of ^
	if parentOp == "^" and isRight and c == p then
		return "(" .. Latex._toLatex(child) .. ")"
	end

	return Latex._toLatex(child)
end

function Latex._toLatex(node)
	local kind = node.kind

	-------------------------------------------------------
	-- Numbers
	-------------------------------------------------------
	if kind == "num" then
		return node.value
	end

	-------------------------------------------------------
	-- Rationals
	-------------------------------------------------------
	if kind == "rat" then
		local n, d = node.num, node.den
		if d == 1 then
			return tostring(n)
		end
		if n < 0 then
			return "-\\frac{" .. tostring(-n) .. "}{" .. tostring(d) .. "}"
		end
		return "\\frac{" .. tostring(n) .. "}{" .. tostring(d) .. "}"
	end

	-------------------------------------------------------
	-- Variables
	-------------------------------------------------------
	if kind == "var" then
		if #node.name > 1 then
			return "\\text{" .. node.name .. "}"
		end
		return node.name
	end

	-------------------------------------------------------
	-- Constants
	-------------------------------------------------------
	if kind == "const" then
		if node.name == "pi" then return "\\pi" end
		if node.name == "phi" then return "\\varphi" end
		if node.name == "tau" then return "\\tau" end
		return node.name
	end

	-------------------------------------------------------
	-- Complex
	-------------------------------------------------------
	if kind == "complex" then
		local realStr = Latex._toLatex(node.real)
		local imagStr = Latex._toLatex(node.imag)

		-- imag part formatting
		if imagStr == "1" then
			imagStr = "i"
		elseif imagStr == "-1" then
			imagStr = "-i"
		else
			imagStr = imagStr .. "i"
		end

		-- cases:
		if realStr == "0" then
			return imagStr
		end

		if node.imag.kind == "num" and node.imag.value:sub(1,1) == "-" then
			return realStr .. " - " .. imagStr:sub(2)
		end

		return realStr .. " + " .. imagStr
	end

	-------------------------------------------------------
	-- Piecewise
	-------------------------------------------------------
	if kind == "piecewise" then
		local out = {}
		table_insert(out, "\\begin{cases}")

		for _, pair in ipairs(node.branches) do
			local cond = Latex._toLatex(pair[1])
			local expr = Latex._toLatex(pair[2])
			table_insert(out, "  " .. expr .. " & \\text{if } " .. cond .. " \\\\")
		end

		table_insert(out, "\\end{cases}")
		return table.concat(out, "\n")
	end

	-------------------------------------------------------
	-- Functions
	-------------------------------------------------------
	if kind == "func" then
		local name = node.name
		local args = node.args

		-- Special case: factorial
		if node.name == "factorial" then
			local arg = node.args[1]
			local inner = Latex._toLatex(arg)

			-- Parenthesize if needed
			if arg.kind == "op" then
				inner = "(" .. inner .. ")"
			end

			return inner .. "!"
		end

		-- Special case: log(a, x)
		if name == "log" and #args == 2 then
			local base = Latex._toLatex(args[1])
			local val  = Latex._toLatex(args[2])
			return "\\log_{" .. base .. "}(" .. val .. ")"
		end

		-- Special case: log10(x)
		if name == "log10" then
			local val = Latex._toLatex(args[1])
			return "\\log_{10}(" .. val .. ")"
		end

		-- Unary
		local latexName = latexNames[node.name] or node.name
		local arg = Latex._toLatex(node.args[1])

		if node.name == "sqrt" then
			return "\\sqrt{" .. arg .. "}"
		end

		if node.name == "abs" then
			return "\\left|" .. arg .. "\\right|"
		end

		-- Not logical operator
		if name == "not" then
			local inner = Latex._toLatex(args[1])
			-- Parenthesize if argument is an op
			if args[1].kind == "op" then
				inner = "(" .. inner .. ")"
			end
			return "\\lnot " .. inner
		end

		-- Parenthesize only if needed
		if node.args[1].kind == "op" then
			arg = "(" .. arg .. ")"
		end

		return "\\" .. latexName .. " " .. arg
	end

	-------------------------------------------------------
	-- Operators
	-------------------------------------------------------
	if kind == "op" then
		local op = node.op
		local L = node.left
		local R = node.right

		---------------------------------------------------
		-- Unary minus
		---------------------------------------------------
		if PrintHelpers.isUnaryMinus(node) then
			local inner = latexParen(R, "u-", false)
			return "-" .. inner
		end

		---------------------------------------------------
		-- Addition
		---------------------------------------------------
		if op == "+" then
			local left = Latex._toLatex(L)
			local right = Latex._toLatex(R)

			-- Fix "+ -x" -> "- x"
			if right:sub(1,1) == "-" then
				return left .. " - " .. right:sub(2)
			end

			return left .. " + " .. right
		end

		---------------------------------------------------
		-- Subtraction
		---------------------------------------------------
		if op == "-" then
			local left = Latex._toLatex(L)
			local right = Latex._toLatex(R)
			return left .. " - " .. right
		end

		---------------------------------------------------
		-- Multiplication (implicit)
		---------------------------------------------------
		if op == "*" then
			-- Flatten chain
			local function collect(n, out)
				if n.kind == "op" and n.op == "*" then
					collect(n.left, out)
					collect(n.right, out)
				else
					table_insert(out, n)
				end
			end

			local factors = {}
			collect(node, factors)

			-- Convert each factor
			local out = {}
			for _, f in ipairs(factors) do
				if PrintHelpers.isSimple(f) then
					table_insert(out, Latex._toLatex(f))
				else
					table_insert(out, "(" .. Latex._toLatex(f) .. ")")
				end
			end

			-- Join with implicit rules
			local result = out[1]
			for i = 2, #out do
				local a = result
				local b = out[i]
				local leftNode = factors[i-1]
				local rightNode = factors[i]

				-- 1 * x -> x
				if leftNode.kind == "num" and leftNode.value == "1" then
					result = b

					-- -1 * x -> -x
				elseif leftNode.kind == "num" and leftNode.value == "-1" then
					result = "-" .. b

					-- number * variable -> 3x
				elseif leftNode.kind == "num" and rightNode.kind == "var" then
					result = a .. b

					-- variable * variable -> xy
				elseif leftNode.kind == "var" and rightNode.kind == "var" then
					result = a .. b

					-- simple * simple -> ab
				elseif PrintHelpers.isSimple(leftNode) and PrintHelpers.isSimple(rightNode) then
					result = a .. b

				else
					result = a .. " " .. b
				end
			end

			return result
		end

		---------------------------------------------------
		-- Division
		---------------------------------------------------
		if op == "/" then
			local left = Latex._toLatex(L)
			local right = Latex._toLatex(R)
			return "\\frac{" .. left .. "}{" .. right .. "}"
		end

		---------------------------------------------------
		-- Exponentiation
		---------------------------------------------------
		if op == "^" then
			local base = latexParen(L, "^", false)
			local exp = latexParen(R, "^", true)
			return base .. "^{" .. exp .. "}"
		end

		---------------------------------------------------
		-- Logical AND / OR
		---------------------------------------------------
		if op == "and" or op == "or" then
			local left = Latex._toLatex(L)
			local right = Latex._toLatex(R)
			local sym = (op == "and") and "\\land" or "\\lor"
			return left .. " " .. sym .. " " .. right
		end

		---------------------------------------------------
		-- Comparisons
		---------------------------------------------------

		if cmpLatex[op] then
			local left = Latex._toLatex(L)
			local right = Latex._toLatex(R)
			return left .. " " .. cmpLatex[op] .. " " .. right
		end
	end

	error("nowayCAS.LaTeX: Unknown node kind '" .. tostring(kind) .. "'")
end

return Latex