local Util = {}

local Node = require(script.Parent.Node)

-------------------------------------------------------
-- Utility Helpers
-------------------------------------------------------

-------------------------------------------------------
-- Nodes and Node Manipulation
-------------------------------------------------------

-- Returns true if node is numeric literal.
function Util.isNum(n)
	return n.kind == "num"
end

-- Returns true if node is variable.
function Util.isVar(n)
	return n.kind == "var"
end

-- Returns true if node is a function.
function Util.isFunc(n)
	return n.kind == "func"
end

-- Returns true if node is complex.
function Util.isComplex(n)
	return n.kind == "complex"
end

-- Returns true if the node is rational.
function Util.isRat(n)
	return n.kind == "rat"
end

-- Returns true if node is constant.
function Util.isConst(n)
	return n.kind == "const"
end

-- Returns true if node is an operator.
function Util.isOp(n)
	return n.kind == "op"
end

-- Returns true if node is an operator.
function Util.isPiecewise(n)
	return n.kind == "piecewise"
end

-- Check if a node is a number or a rational kind.
function Util.isNumeric(n)
	return n.kind == "num" or n.kind == "rat"
end

-- Convert Node.Num or Node.Rat -> (num, den)
function Util.toRational(n)
	if n.kind == "num" then
		return tonumber(n.value), 1
	elseif n.kind == "rat" then
		return n.num, n.den
	end
end

-- Convert rational pair -> Node.Num or Node.Rat
-- Returns nil if the rational cannot be represented exactly.
function Util.fromRational(num, den)
	-- Guard: numerator and denominator must be within safe integer range
	if math.abs(num) > 2^53 or math.abs(den) > 2^53 then
		return nil
	end

	-- reduce
	local g = Util.gcd(num, den)
	num = num // g
	den = den // g

	-- Guard again after reduction
	if math.abs(num) > 2^53 or math.abs(den) > 2^53 then
		return nil
	end

	-- If denominator is 1, return integer node
	if den == 1 then
		return Node.Num(tostring(num))
	end

	-- Otherwise return rational node
	return Node.Rat(num, den)
end

-- Returns true if the node is zero.
function Util.isZero(n)
	if n.kind == "num" then
		return n.value == "0"
	elseif n.kind == "rat" then
		return n.num == 0
	end
	return false
end

-- Returns true if the node is negative one.
function Util.isNegOne(n)
	if n.kind == "num" then
		return n.value == "-1"
	elseif n.kind == "rat" then
		return n.num == -1 and n.den == 1
	end
	return false
end

-- Returns true if the node is one.
function Util.isOne(n)
	if n.kind == "num" then
		return n.value == "1"
	elseif n.kind == "rat" then
		return n.num == 1 and n.den == 1
	end
	return false
end

-- Returns true if the node is true.
function Util.isTrue(n)
	return n.kind == "const" and n.name == "true"
end

-- Returns true if the node is false.
function Util.isFalse(n)
	return n.kind == "const" and n.name == "false"
end

-- Checks if the instance is a node.
function Util.isNode(x)
	return type(x) == "table" and x.kind ~= nil
end

-- Checks if the first node is structurally identical to the second node.
function Util.nodeEquals(a, b)
	if a == b then return true end
	if a.kind ~= b.kind then return false end

	if Util.isNum(a) then
		return a.value == b.value

	elseif Util.isVar(a) then
		return a.name == b.name

	elseif Util.isFunc(a) then
		return a.name == b.name
			and Util.nodeEquals(a.args, b.args)

	elseif Util.isOp(a) then
		return a.op == b.op
			and Util.nodeEquals(a.left, b.left)
			and Util.nodeEquals(a.right, b.right)

	end

	return false
end

-- Checks if two arrays of AST nodes are structurally identical.
-- Each list must have the same length and every corresponding element
function Util.nodeListEquals(a, b)
	if #a ~= #b then
		return false
	end

	for i = 1, #a do
		if not Util.nodeEquals(a[i], b[i]) then
			return false
		end
	end

	return true
end

-- Build a variable or a constant.
function Util.buildSymbol(name)
	if name:sub(1,6) == "const:" then
		return Node.Const(name:sub(7))
	else
		return Node.Var(name)
	end
end

-- Collects all variable names appearing anywhere in an AST.
-- Returns an array of unique variable names (strings).
function Util.collectVars(node)
	local out = {}
	local seen = {}

	local function walk(n)
		if Util.isVar(n) then
			local name = n.name
			if not seen[name] then
				seen[name] = true
				table.insert(out, name)
			end
			return
		end

		if Util.isOp(n) then
			walk(n.left)
			walk(n.right)
			return
		end

		if Util.isFunc(n) then
			for _, arg in ipairs(n.args) do
				walk(arg)
			end
			return
		end

		-- num, rat, const: no variables inside
	end

	walk(node)
	return out
end

-- Collect polynomial coefficients in var
-- Returns a table: degree -> coefficient expression
-- or nil if not a polynomial.
function Util.collectCoefficients(expr, var)
	local function collect(node)
		-- Constant
		if Util.isNumeric(node) then
			return { [0] = node }
		end

		-- Variable
		if Util.isVar(node) then
			if node.name == var.name then
				return { [1] = Node.Num("1") }
			else
				return { [0] = node }
			end
		end

		-- Operator
		if Util.isOp(node) then
			local op = node.op
			local a, b = node.left, node.right

			if op == "+" then
				local ca = collect(a)
				local cb = collect(b)
				if not ca or not cb then return nil end

				local out = {}
				for d, coeff in pairs(ca) do out[d] = coeff end
				for d, coeff in pairs(cb) do
					if out[d] then
						out[d] = Node.Op("+", out[d], coeff)
					else
						out[d] = coeff
					end
				end
				return out
			end

			if op == "*" then
				local ca = collect(a)
				local cb = collect(b)
				if not ca or not cb then return nil end

				local out = {}
				for da, ca_val in pairs(ca) do
					for db, cb_val in pairs(cb) do
						local deg = da + db
						local prod = Node.Op("*", ca_val, cb_val)
						if out[deg] then
							out[deg] = Node.Op("+", out[deg], prod)
						else
							out[deg] = prod
						end
					end
				end
				return out
			end

			if op == "^" then
				-- Only allow var^n where n is numeric
				if Util.isVar(a) and a.name == var.name and Util.isNum(b) then
					local n = tonumber(b.value)
					if not n or n < 0 then return nil end
					return { [n] = Node.Num("1") }
				end
				return nil
			end

			return nil
		end

		-- Functions, constants, etc. are not polynomials
		return nil
	end

	return collect(expr)
end

-------------------------------------------------------
-- Mathematical functions
-------------------------------------------------------

-- Great Common Divisor
function Util.gcd(a, b)
	a = math.floor(math.abs(a))
	b = math.floor(math.abs(b))

	while b ~= 0 do
		a, b = b, a % b
	end

	return a
end

-- Factorial
function Util.factorial(n)
	local r = 1
	for i = 2, n do
		r *= i
	end
	return r
end

-------------------------------------------------------
-- Equation Helpers
-------------------------------------------------------

-- Detect if the string has a relation and then split into two left and right expressions and one relation if found.
function Util.detectRelation(str)
	-- Relations to detect, ordered by length (longest first)
	local relations = { "<=", ">=", "!=", "==", "<", ">", "=" }

	local depth = 0
	local i = 1
	local len = #str

	while i <= len do
		local c = str:sub(i, i)

		-- Track parentheses depth
		if c == "(" or c == "{" or c == "[" then
			depth += 1
		elseif c == ")" or c == "}" or c == "]" then
			depth -= 1
		end

		-- Only detect relations at top level
		if depth == 0 then
			-- Try multi-character relations first
			for _, rel in ipairs(relations) do
				local rlen = #rel
				if str:sub(i, i + rlen - 1) == rel then
					-- Split into lhs, rhs
					local lhs = str:sub(1, i - 1)
					local rhs = str:sub(i + rlen)

					-- Trim whitespace
					lhs = lhs:match("^%s*(.-)%s*$")
					rhs = rhs:match("^%s*(.-)%s*$")

					return lhs, rel, rhs
				end
			end
		end

		i += 1
	end

	-- No top-level relation found
	return nil
end

-------------------------------------------------------
-- First-class Helpers
-------------------------------------------------------

-- Returns true if the object is an equation.
function Util.isEquation(a)
	if a.kind and a.kind == "equation" then return true end
	return false
end

-- Returns true if the object is an equation.
function Util.isExpression(a)
	if a.kind and a.kind == "expression" then return true end
	return false
end


-- The Utility sub-library.
return Util