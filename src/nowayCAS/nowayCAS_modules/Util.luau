local Util = {}

local Node = require(script.Parent.Node)

-------------------------------------------------------
-- Utility Helpers
-------------------------------------------------------

-- Checks if the instance is a node.
function Util.isNode(x)
	return type(x) == "table" and x.kind ~= nil
end

-- Checks if the first node is equal to the second node.
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

-- The Utility sub-library
return Util