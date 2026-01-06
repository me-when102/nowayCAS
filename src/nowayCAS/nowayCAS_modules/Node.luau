local Node = {}
local NODE_CACHE = {}

local tostring = tostring

-------------------------------------------------------
-- Expression Node Constructors
-------------------------------------------------------

-- Hashes the node (DAG)
local function hashNode(kind, a, b, c)
	return kind .. "|" ..
		tostring(a) .. "|" ..
		tostring(b) .. "|" ..
		tostring(c)
end

-- Hashes args (prevent printing table) (DAG)
local function hashArgs(args)
	if not args or #args == 0 then
		return ""
	end

	local parts = {}
	for i = 1, #args do
		parts[i] = tostring(args[i])
	end

	return table.concat(parts, ",")
end

-- Constructs a node as a number with a value.
function Node.Num(n) 
	local v = tostring(tonumber(n))

	local key = hashNode("num", v, "", "")
	local existing = NODE_CACHE[key]
	if existing then return existing end

	local node = { kind = "num", value = v }
	NODE_CACHE[key] = node
	return node
end

-- Great Common Divisor
-- You are not getting depended on Util.
local function gcd(a, b)
	while b ~= 0 do
		a, b = b, a % b
	end
	return a
end

-- Constructs a node as a rational number a/b.
function Node.Rat(n, d)
	-- Normalize inputs
	n = tonumber(n)
	d = tonumber(d)

	if d == 0 then
		error("Node.Rat: denominator cannot be zero")
	end

	-- Normalize sign: denominator always positive
	if d < 0 then
		n = -n
		d = -d
	end

	-- Reduce by gcd
	local g = gcd(math.abs(n), d)
	n = n // g
	d = d // g

	-- Zero is always 0/1
	if n == 0 then
		d = 1
	end

	local key = hashNode("rat", n, d, "")
	local existing = NODE_CACHE[key]
	if existing then return existing end

	local node = { kind = "rat", num = n, den = d }
	NODE_CACHE[key] = node
	return node
end

-- Constructs a node as a complex number: real + imag*i
function Node.Complex(real, imag)
	-- real and imag must be numeric nodes (num or rat)
	if real == nil or imag == nil then
		error("Node.Complex: missing real or imaginary part")
	end

	-- Hash key: kind | real | imag
	local key = hashNode("complex", real, imag, "")

	local existing = NODE_CACHE[key]
	if existing then
		return existing
	end

	local node = {
		kind = "complex",
		real = real,   -- Node.Num or Node.Rat
		imag = imag,   -- Node.Num or Node.Rat
	}

	NODE_CACHE[key] = node
	return node
end

-- Constructs a node as a variable with a name.
function Node.Var(name) 
	local key = hashNode("var", name, "", "")
	local existing = NODE_CACHE[key]
	if existing then return existing end


	local node = { kind = "var", name = name } 
	NODE_CACHE[key] = node
	return node
end

-- Constructs a node as an operator with two nodes 'left' and 'right' and the operator identifier.
function Node.Op(op, left, right)
	if left == nil or right == nil then
		error(("Node.Op: missing child for '%s' (left=%s, right=%s)"):format(
			tostring(op),
			left and "ok" or "nil",
			right and "ok" or "nil"
			))
	end

	local key = hashNode("op", op, left, right)
	local existing = NODE_CACHE[key]
	if existing then return existing end

	local node = { kind = "op", op = op, left = left, right = right }
	NODE_CACHE[key] = node
	return node
end

-- Constructs a node as a function with a name and arguments.
function Node.Func(name, args)
	-- Compute structural hash of argument list
	local argKey = hashArgs(args)

	local key = hashNode("func", name, argKey, "")
	local existing = NODE_CACHE[key]
	if existing then return existing end

	local node = { kind = "func", name = name, args = args }
	NODE_CACHE[key] = node
	return node
end

-- Constructs a node as a constant with a name.
function Node.Const(name)
	local key = hashNode("const", name, "", "")
	local existing = NODE_CACHE[key]
	if existing then return existing end
	local node = { kind = "const", name = name }
	NODE_CACHE[key] = node
	return node
end

-- The Node sub-library.
return Node