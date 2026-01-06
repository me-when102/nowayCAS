local Util = {}

local Node = require(script.Parent.Node)

-------------------------------------------------------
-- Utility Helpers
-------------------------------------------------------

-------------------------------------------------------
-- Nodes
-------------------------------------------------------

-- Checks if the instance is a node.
function Util.isNode(x)
	return type(x) == "table" and x.kind ~= nil
end

-- Checks if the first node is structurally identical to the second node.
function Util.nodeEquals(a, b)
	if a == b then return true end
	if a.kind ~= b.kind then return false end

	if a.kind == "num" then
		return a.value == b.value
	elseif a.kind == "var" then
		return a.name == b.name
	elseif a.kind == "func" then
		return a.name == b.name
			and Util.nodeEquals(a.args, b.args)
	elseif a.kind == "op" then
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
		if n.kind == "var" then
			local name = n.name
			if not seen[name] then
				seen[name] = true
				table.insert(out, name)
			end
			return
		end

		if n.kind == "op" then
			walk(n.left)
			walk(n.right)
			return
		end

		if n.kind == "func" then
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
		local kind = node.kind

		-- Constant
		if kind == "num" or kind == "rat" then
			return { [0] = node }
		end

		-- Variable
		if kind == "var" then
			if node.name == var.name then
				return { [1] = Node.Num("1") }
			else
				return { [0] = node }
			end
		end

		-- Operator
		if kind == "op" then
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
				if a.kind == "var" and a.name == var.name and b.kind == "num" then
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
	local relations = { "<=", ">=", "!=", "<", ">", "=" }

	local depth = 0
	local i = 1
	local len = #str

	while i <= len do
		local c = str:sub(i, i)

		-- Track parentheses depth
		if c == "(" then
			depth += 1
		elseif c == ")" then
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

-- The Utility sub-library
return Util