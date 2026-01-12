local String = {}

local Util = require(script.Parent.Parent.Util)
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
	if Util.isRat(node) then
		return "(" .. s .. ")"
	end
	return s
end

-- Wrap child in parentheses / brackets if needed
local function maybeParen(child, parentOp, isRight)
	if not Util.isOp(child) then
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

	if Util.isNum(node) then
		return node.value
	end

	if Util.isRat(node) then
		return tostring(node.num) .. "/" .. tostring(node.den)
	end

	if Util.isVar(node) then
		return node.name
	end

	if Util.isConst(node) then
		return PrintHelpers.unicodeConstants[node.name] or node.name
	end

	if Util.isComplex(node) then
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

		if Util.isNum(node.imag) and node.imag.value:sub(1,1) == "-" then
			return realStr .. " - " .. imagStr:sub(2)
		end

		return realStr .. " + " .. imagStr
	end

	if Util.isFunc(node) then

		-- Special case: factorial
		if node.name == "factorial" then
			local arg = node.args[1]
			local inner = String._toString(arg)

			-- Parenthesize if argument is not simple
			if Util.isOp(arg) or Util.isFunc(arg) then
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

	if Util.isPiecewise(node) then
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

	if Util.isOp(node) then
		local op = node.op

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
			-- Flatten the multiplication chain
			local factors = {}
			local function collect(n)
				if Util.isOp(n) and n.op == "*" then
					collect(n.left)
					collect(n.right)
				else
					table_insert(factors, n)
				end
			end
			collect(node)

			-- Look for -1 factors and remove them while tracking sign
			local sign = 1
			local nonNegFactors = {}
			for _, f in ipairs(factors) do
				if Util.isNum(f) and f.value == "-1" then
					sign = -sign
				else
					table_insert(nonNegFactors, f)
				end
			end

			-- If we ended up with no factors left after removing -1's → it's 1 or -1
			if #nonNegFactors == 0 then
				return sign < 0 and "-1" or "1"
			end

			-- Build the string for the remaining factors with implicit rules
			local parts = {}
			for _, f in ipairs(nonNegFactors) do
				local s = String._toString(f, "*")
				if not PrintHelpers.isSimple(f) then
					s = "(" .. s .. ")"
				end
				table_insert(parts, s)
			end
			
			-- Join factors using implicit multiplication rules
			local joined = parts[1] or "1"
			for i = 2, #parts do
				local leftNode  = nonNegFactors[i-1]
				local rightNode = nonNegFactors[i]
				local a = joined
				local b = parts[i]

				if Util.isNumeric(leftNode) and Util.isVar(rightNode) then
					joined = wrapIfRat(leftNode, a) .. b          	-- 2x

				elseif Util.isNumeric(leftNode) and PrintHelpers.isBareVar(rightNode) then
					joined = a .. wrapIfRat(rightNode, b)         	-- x2 (rare)

				elseif PrintHelpers.isBareVar(leftNode) and PrintHelpers.isBareVar(rightNode) then
					if #leftNode.name > 1 or #rightNode.name > 1 then
						joined = a .. " * " .. b					-- multi-letter vars -> explicit
					else
						joined = a .. b                             -- xy
					end

				elseif PrintHelpers.isSimple(leftNode) and Util.isOp(rightNode) then
					joined = wrapIfRat(leftNode, a) .. b			-- simple * complex-op

				elseif Util.isOp(leftNode) and PrintHelpers.isSimple(rightNode) then
					joined = a .. wrapIfRat(rightNode, b)			-- op * op -> implicit

				elseif Util.isOp(leftNode) and Util.isOp(rightNode) then
					joined = a .. b									-- fallback explicit multiplication

				else
					joined = a .. " * " .. b

				end
			end

			-- Apply overall sign
			if sign < 0 then
				return "-" .. joined
			end

			return joined
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