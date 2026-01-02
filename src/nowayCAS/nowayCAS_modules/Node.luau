local Node = {}
local NODE_CACHE = {}

local tostring = tostring

-------------------------------------------------------
-- Expression Node Constructors
-------------------------------------------------------

local function hashNode(kind, a, b, c)
	return kind .. "|" ..
		tostring(a) .. "|" ..
		tostring(b) .. "|" ..
		tostring(c)
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

-- Constructs a node as a variable with a name.
function Node.Var(name) 
	local key = hashNode("var", name, "", "")
	local existing = NODE_CACHE[key]
	if existing then return existing end


	local node = { kind = "var", name = name } 
	NODE_CACHE[key] = node
	return node
end

-- Constructs a node as an operator with two nodes 'left' and 'right' and the operator identifier..
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
function Node.Func(name, arg)
	local key = hashNode("func", name, arg, "")
	local existing = NODE_CACHE[key]
	if existing then return existing end

	local node = {kind = "func", name = name, arg = arg }
	NODE_CACHE[key] = node
	return node
end

-- The Node sub-library.
return Node