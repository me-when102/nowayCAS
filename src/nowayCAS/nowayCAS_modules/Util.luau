local Util = {}

-------------------------------------------------------
-- Utility Helpers
-------------------------------------------------------

-- Checks if the instance is a node.
function Util.isNode(x)
	return type(x) == "table" and x.kind ~= nil
end

function Util.nodeEquals(a, b)
	if a == b then return true end
	if a.kind ~= b.kind then return false end

	if a.kind == "num" then
		return a.value == b.value
	elseif a.kind == "var" then
		return a.name == b.name
	elseif a.kind == "func" then
		return a.name == b.name
			and Util.nodeEquals(a.arg, b.arg)
	elseif a.kind == "op" then
		return a.op == b.op
			and Util.nodeEquals(a.left, b.left)
			and Util.nodeEquals(a.right, b.right)
	end

	return false
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

-- The Utility sub-library
return Util