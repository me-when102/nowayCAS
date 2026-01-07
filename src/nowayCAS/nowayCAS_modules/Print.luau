local Print = {}

local table_insert = table.insert
local ipairs = ipairs

-------------------------------------------------------
-- Pretty Printer
-- Converts an AST back into a readable expression string.
-- Respects operator precedence and inserts parentheses only
-- when necessary.
-------------------------------------------------------

local PRECEDENCE = {
	["+"] = 1,
	["-"] = 1,
	["*"] = 2,
	["/"] = 2,
	["u-"] = 3,
	["^"] = 4,
}

local unicodeConstants = {
	pi  = "π",
	phi = "φ",
	tau = "τ",
}

-- Wraps the rational in paranthesis / brackets if rational
local function wrapIfRat(node, s)
	if node.kind == "rat" then
		return "(" .. s .. ")"
	end
	return s
end

-- Wrap child in parentheses / brackets if needed
local function maybeParen(child, parentOp, isRight)
	if child.kind ~= "op" then
		return Print._toString(child, parentOp)
	end

	local childPrec = PRECEDENCE[child.op]
	local parentPrec = PRECEDENCE[parentOp] or 0

	-- Special case: 1 / (a * b) must keep parentheses
	if parentOp == "/" and isRight and child.op == "*" then
		return "(" .. Print._toString(child, parentOp) .. ")"
	end

	-- Lower precedence -> must wrap
	if childPrec < parentPrec then
		return "(" .. Print._toString(child, parentOp) .. ")"
	end

	-- Right-associativity of ^
	if parentOp == "^" and isRight and childPrec == parentPrec then
		return "(" .. Print._toString(child, parentOp) .. ")"
	end

	return Print._toString(child, parentOp)
end

-- Helper to format operators.
local function formatOp(op, left, right)
	if op == "+" and right:sub(1,1) == "-" then
		return left .. " - " .. right:sub(2)
	end
	if op == "-" and right:sub(1,1) == "-" then
		return left .. " + " .. right:sub(2)
	end
	return left .. " " .. op .. " " .. right
end

-- Checks if the node is a variable
local function isBareVar(n)
	return (n.kind == "var" or n.kind == "const")
end

-- Checks if the node is just var^number.
local function isSimplePower(n)
	return n.kind == "op"
		and n.op == "^"
		and n.left.kind == "var"
		and n.right.kind == "num"
end

-- Checks if the node is a simple variable.
local function isSimple(n)
	return n.kind == "num"
		or n.kind == "rat"
		or n.kind == "var"
		or n.kind == "func"
		or n.kind == "const"
		or isSimplePower(n)
end

-- Checks if n is just one letter.
local function isSingleVarName(n)
	return n.kind == "var" and #n.name > 1
end

-- Converts the node into a readable string. (INTERNAL)
function Print._toString(node, parentOp)
	local kind = node.kind

	if kind == "num" then
		return node.value
	end

	if kind == "rat" then
		return tostring(node.num) .. "/" .. tostring(node.den)
	end

	if kind == "var" then
		return node.name
	end

	if kind == "const" then
		return unicodeConstants[node.name] or node.name
	end

	if kind == "complex" then
		local realStr = Print._toString(node.real)
		local imagStr = Print._toString(node.imag)

		-- imag part formatting
		if imagStr == "1" then
			imagStr = "i"
		elseif imagStr == "-1" then
			imagStr = "-i"
		else
			imagStr = imagStr .. "i"
		end

		-- cases:
		-- a + bi
		-- a - bi
		-- bi
		-- a
		if realStr == "0" then
			return imagStr
		end

		if node.imag.kind == "num" and node.imag.value:sub(1,1) == "-" then
			return realStr .. " - " .. imagStr:sub(2)
		end

		return realStr .. " + " .. imagStr
	end

	if kind == "func" then

		-- Special case: factorial
		if node.name == "factorial" then
			local arg = node.args[1]
			local inner = Print._toString(arg)

			-- Parenthesize if argument is not simple
			if arg.kind == "op" or arg.kind == "func" then
				inner = "(" .. inner .. ")"
			end

			return inner .. "!"
		end

		-- Convert each argument to string
		local parts = {}
		for i, a in ipairs(node.args) do
			parts[i] = Print._toString(a)
		end

		return node.name .. "(" .. table.concat(parts, ", ") .. ")"
	end

	if kind == "op" then
		local op = node.op

		-------------------------------------------------------
		-- Unary minus
		-------------------------------------------------------
		if op == "*" and node.left.kind == "num" and node.left.value == "-1" then
			local inner = maybeParen(node.right, "u-", false)
			return "-" .. inner
		end

		-------------------------------------------------------
		-- Exponentiation
		-------------------------------------------------------
		if op == "^" then
			local left = maybeParen(node.left, "^", false)
			local right = maybeParen(node.right, "^", true)
			return left .. "^" .. right
		end

		-------------------------------------------------------
		-- Multiplication (flatten + smart implicit mult)
		-------------------------------------------------------
		if op == "*" then
			-- 1. Flatten chain
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

			-- 2. Convert each factor to string
			local out = {}
			for _, f in ipairs(factors) do
				if isSimple(f) then
					table_insert(out, Print._toString(f, "*"))
				else
					table_insert(out, "(" .. Print._toString(f, "*") .. ")")
				end
			end

			-- 3. Join with correct implicit multiplication rules
			local result = out[1]
			for i = 2, #out do
				local leftNode = factors[i-1]
				local rightNode = factors[i]
				local a = result
				local b = out[i]

				-- number * variable -> 3x
				if (leftNode.kind == "num" or leftNode.kind == "rat")
					and rightNode.kind == "var" then

					result = wrapIfRat(leftNode, a) .. b

					-- variable * number -> 3x
				elseif (leftNode.kind == "num" or leftNode.kind == "rat")
					and isBareVar(rightNode) then

					result = a .. wrapIfRat(rightNode, b)

					-- variable * variable
				elseif isBareVar(leftNode) and isBareVar(rightNode) then
					-- multi-letter vars must NOT concatenate
					if #leftNode.name > 1 or #rightNode.name > 1 then
						result = a .. " * " .. b
					else
						-- single-letter vars stay intact.
						result = a .. b
					end
					-- simple * composite -> x(...)
				elseif isSimple(leftNode) and rightNode.kind == "op" then
					result = wrapIfRat(leftNode, a) .. b

					-- composite * simple -> (... )x
				elseif leftNode.kind == "op" and isSimple(rightNode) then
					result = a .. wrapIfRat(rightNode, b)

					-- composite * composite -> (...)(...)
				elseif leftNode.kind == "op" and rightNode.kind == "op" then
					result = a .. b

				else
					result = a .. " * " .. b
				end
			end

			return result
		end

		-------------------------------------------------------
		-- Default binary operator
		-------------------------------------------------------
		local left = maybeParen(node.left, op, false)
		local right = maybeParen(node.right, op, true)
		return formatOp(op, left, right)
	end

	error("nowayCAS.Print: Unknown node kind '" .. tostring(kind) .. "'")
end

-------------------------------------------------------
-- DAG-Aware Pretty Printer
-- Detects shared subexpressions and names them (t1, t2, ...)
-------------------------------------------------------

-- Count references to each node in the DAG
local function countRefs(root)
	local counts = {}
	local order = {}

	local function visit(node)
		if counts[node] then
			counts[node] += 1
			return
		end

		counts[node] = 1
		table_insert(order, node)

		if node.kind == "op" then
			visit(node.left)
			visit(node.right)
		elseif node.kind == "func" then
			visit(node.arg)
		end
	end

	visit(root)
	return counts, order
end

-- Converts the node into a DAG string.
function Print._toDAGString(root)
	local counts, order = countRefs(root)

	-- Assign names to repeated nodes
	local names = {}
	local counter = 1
	for _, node in ipairs(order) do
		if counts[node] > 1 then
			names[node] = "t" .. counter
			counter += 1
		end
	end

	local out = {}

	-- Emit definitions for repeated subexpressions
	for _, node in ipairs(order) do
		local name = names[node]
		if name then
			table_insert(out, name .. " = " .. Print._toString(node))
		end
	end

	-- Emit final expression
	table_insert(out, "result = " .. Print._toString(root))

	return table.concat(out, "\n")
end

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

-- Get precedence of the node for LaTeX.
local function latexPrec(node)
	if node.kind ~= "op" then
		return 10
	end
	return PRECEDENCE[node.op] or 10
end

-- Wrap parenthesis / brackets determined by precedence for LaTeX.
local function latexParen(child, parentOp, isRight)
	if child.kind ~= "op" then
		return Print._toLatex(child)
	end

	local c = latexPrec(child)
	local p = PRECEDENCE[parentOp] or 0

	-- Lower precedence -> must wrap
	if c < p then
		return "(" .. Print._toLatex(child) .. ")"
	end

	-- Right-associativity of ^
	if parentOp == "^" and isRight and c == p then
		return "(" .. Print._toLatex(child) .. ")"
	end

	return Print._toLatex(child)
end

-- Checks if the node is a unary minus.
local function isUnaryMinus(node)
	return node.kind == "op"
		and node.op == "*"
		and node.left.kind == "num"
		and node.left.value == "-1"
end

function Print._toLatex(node)
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
		local realStr = Print._toLatex(node.real)
		local imagStr = Print._toLatex(node.imag)

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
	-- Functions
	-------------------------------------------------------
	if kind == "func" then
		local name = node.name
		local args = node.args

		-- Special case: factorial
		if node.name == "factorial" then
			local arg = node.args[1]
			local inner = Print._toLatex(arg)

			-- Parenthesize if needed
			if arg.kind == "op" then
				inner = "(" .. inner .. ")"
			end

			return inner .. "!"
		end

		-- Special case: log(a, x)
		if name == "log" and #args == 2 then
			local base = Print._toLatex(args[1])
			local val  = Print._toLatex(args[2])
			return "\\log_{" .. base .. "}(" .. val .. ")"
		end

		-- Special case: log10(x)
		if name == "log10" then
			local val = Print._toLatex(args[1])
			return "\\log_{10}(" .. val .. ")"
		end

		-- Unary
		local latexName = latexNames[node.name] or node.name
		local arg = Print._toLatex(node.args[1])

		if node.name == "sqrt" then
			return "\\sqrt{" .. arg .. "}"
		end

		if node.name == "abs" then
			return "\\left|" .. arg .. "\\right|"
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
		if isUnaryMinus(node) then
			local inner = latexParen(R, "u-", false)
			return "-" .. inner
		end

		---------------------------------------------------
		-- Addition
		---------------------------------------------------
		if op == "+" then
			local left = Print._toLatex(L)
			local right = Print._toLatex(R)

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
			local left = Print._toLatex(L)
			local right = Print._toLatex(R)
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
				if isSimple(f) then
					table_insert(out, Print._toLatex(f))
				else
					table_insert(out, "(" .. Print._toLatex(f) .. ")")
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
				elseif isSimple(leftNode) and isSimple(rightNode) then
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
			local left = Print._toLatex(L)
			local right = Print._toLatex(R)
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
	end

	error("nowayCAS.LaTeX: Unknown node kind '" .. tostring(kind) .. "'")
end

-------------------------------------------------------
-- AST Representation Debug
-- Prints the AST.
-------------------------------------------------------

-- Returns a shallow table representation of the AST (safe for printing / tests)
local function nodeToTable(node)
	if not node then return nil end
	local t = { kind = node.kind }
	if node.kind == "num" then
		t.value = node.value
	elseif node.kind == "var" then
		t.name = node.name
	elseif node.kind == "const" then
		t.name = node.name
	elseif node.kind == "complex" then
		t.real = nodeToTable(node.real)
		t.imag = nodeToTable(node.imag)
	elseif node.kind == "func" then
		t.name = node.name
		t.args = {}
		for i, a in ipairs(node.args) do
			t.args[i] = nodeToTable(a)
		end
	elseif node.kind == "op" then
		t.op = node.op
		t.left = nodeToTable(node.left)
		t.right = nodeToTable(node.right)
	end
	return t
end

-- Build an indented, human-readable representation
local function nodeToIndented(node, level, out)
	level = level or 0
	local indent = string.rep("  ", level)

	if not node then
		table_insert(out, indent .. "<nil>")

	elseif node.kind == "num" then
		table_insert(out, indent .. ("Num value=%s"):format(tostring(node.value)))

	elseif node.kind == "var" then
		table_insert(out, indent .. ("Var name=%s"):format(tostring(node.name)))

	elseif node.kind == "const" then
		table_insert(out, indent .. ("Const name=%s"):format(tostring(node.name)))

	elseif node.kind == "complex" then
		table_insert(out, indent .. "Complex")
		nodeToIndented(node.real, level + 1, out)
		nodeToIndented(node.imag, level + 1, out)

	elseif node.kind == "func" then
		table_insert(out, indent .. ("Func name=%s"):format(tostring(node.name)))
		for _, a in ipairs(node.args) do
			nodeToIndented(a, level + 1, out)
		end

	elseif node.kind == "op" then
		table_insert(out, indent .. ("Op %s"):format(tostring(node.op)))
		nodeToIndented(node.left, level + 1, out)
		nodeToIndented(node.right, level + 1, out)

	else
		table_insert(out, indent .. ("<unknown kind=%s>"):format(tostring(node.kind)))
	end
end

-- Returns a table and an indented string
function Print.toASTRepresentation(root)
	-- raw table (safe to compare in tests)
	local raw = nodeToTable(root)
	-- indented string for logs
	local lines = {}
	nodeToIndented(root, 0, lines)
	local indented = table.concat(lines, "\n")
	return {
		raw = raw,
		indented = indented,
	}
end

-------------------------------------------------------
-- Value Pretty Printer
-------------------------------------------------------

-- Assuming { complex = boolean, imag = num, real = num },
-- Returns a string of the complex number representation
local function prettyComplex(z)
	local r = z.real
	local i = z.imag
	
	-- Pure real
	if i == 0 then
		return tostring(r)
	end
	
	-- Pure imaginary
	if r == 0 then
		if i == 1 then return "i" end
		if i == -1 then return "-i" end
		return tostring(i) .. "i"
	end
	
	-- Mixed real + imaginary
	local sign = i >= 0 and " + " or " - "
	local imagAbs = math.abs(i)
	
	if imagAbs == 1 then
		return tostring(r) .. sign .. "i"
	else
		return tostring(r) .. sign .. tostring(imagAbs) .. "i"
	end
end

-- Converts a value (including complex numbers) into a human-readable string.
function Print.value(v)
	if type(v) == "table" and v._complex then
		return prettyComplex(v)
	else
		return tostring(v)
	end
end

-- The Printing sub-library.
return Print