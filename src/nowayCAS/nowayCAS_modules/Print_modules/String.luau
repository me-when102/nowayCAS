local String = {}

local PrintHelpers = require(script.Parent.PrintHelpers)

local table_insert = table.insert

-------------------------------------------------------
-- Pretty Printer
-- Converts an AST back into a readable expression string.
-- Respects operator precedence and inserts parentheses only
-- when necessary.
-------------------------------------------------------

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
		return String._toString(child, parentOp)
	end

	local childPrec = PrintHelpers.PRECEDENCE[child.op]
	local parentPrec = PrintHelpers.PRECEDENCE[parentOp] or 0

	-- Special case: 1 / (a * b) must keep parentheses
	if parentOp == "/" and isRight and child.op == "*" then
		return "(" .. String._toString(child, parentOp) .. ")"
	end

	-- Lower precedence -> must wrap
	if childPrec < parentPrec then
		return "(" .. String._toString(child, parentOp) .. ")"
	end

	-- Right-associativity of ^
	if parentOp == "^" and isRight and childPrec == parentPrec then
		return "(" .. String._toString(child, parentOp) .. ")"
	end

	return String._toString(child, parentOp)
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

-- Converts the node into a readable string.
function String._toString(node, parentOp)
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
		return PrintHelpers.unicodeConstants[node.name] or node.name
	end

	if kind == "complex" then
		local realStr = String._toString(node.real)
		local imagStr = String._toString(node.imag)

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
			local inner = String._toString(arg)

			-- Parenthesize if argument is not simple
			if arg.kind == "op" or arg.kind == "func" then
				inner = "(" .. inner .. ")"
			end

			return inner .. "!"
		end

		-- Convert each argument to string
		local parts = {}
		for i, a in ipairs(node.args) do
			parts[i] = String._toString(a)
		end

		return node.name .. "(" .. table.concat(parts, ", ") .. ")"
	end

	if kind == "piecewise" then
		local lines = {}
		table_insert(lines, "{")

		for _, pair in ipairs(node.branches) do
			local condStr = String._toString(pair[1])
			local exprStr = String._toString(pair[2])
			table_insert(lines, "  " .. condStr .. " : " .. exprStr .. ";")
		end

		table_insert(lines, "}")
		return table.concat(lines, "\n")
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
				if PrintHelpers.isSimple(f) then
					table_insert(out, String._toString(f, "*"))
				else
					table_insert(out, "(" .. String._toString(f, "*") .. ")")
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
					and PrintHelpers.isBareVar(rightNode) then

					result = a .. wrapIfRat(rightNode, b)

					-- variable * variable
				elseif PrintHelpers.isBareVar(leftNode) and PrintHelpers.isBareVar(rightNode) then
					-- multi-letter vars must NOT concatenate
					if #leftNode.name > 1 or #rightNode.name > 1 then
						result = a .. " * " .. b
					else
						-- single-letter vars stay intact.
						result = a .. b
					end
					-- simple * composite -> x(...)
				elseif PrintHelpers.isSimple(leftNode) and rightNode.kind == "op" then
					result = wrapIfRat(leftNode, a) .. b

					-- composite * simple -> (... )x
				elseif leftNode.kind == "op" and PrintHelpers.isSimple(rightNode) then
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

return String