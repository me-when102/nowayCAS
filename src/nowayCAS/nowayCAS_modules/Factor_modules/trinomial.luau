local Tri = {}

local FactorHelpers = require(script.Parent.FactorHelpers)
local Simplify = require(script.Parent.Parent.Simplify)
local Node = require(script.Parent.Parent.Node)

-------------------------------------------------------
-- Trinomial
-------------------------------------------------------

-- Factorizes the node if the onde is a perfect square trinomial.
function Tri.isPerfectSquareTrinomial(node)
	if node.kind ~= "op" or node.op ~= "+" then return nil end

	local terms = {}
	FactorHelpers.factor_flatten(node, "+", terms)
	if #terms ~= 3 then return nil end

	local squares = {}
	local middle = nil

	for _, t in ipairs(terms) do
		local isSq, base, sign = FactorHelpers.getSquareBaseSigned(t)
		if isSq then
			table.insert(squares, {base=base, sign=sign, node=t})
		else
			middle = t
		end
	end

	if #squares ~= 2 or not middle then return nil end

	local u = squares[1].base
	local v = squares[2].base

	-- Try both orders (u^2 + 2uv + v^2 or v^2 + 2vu + u^2)
	local uv = Node.Op("*", u, v)
	local expected = Node.Op("*", Node.Num("2"), uv)

	-- Check if middle == +-2uv (after simplify)
	local ratio = Simplify.simplify(Node.Op("/", middle, uv))
	if ratio.kind == "num" then
		local k = tonumber(ratio.value)
		if k == 2 then return Node.Op("^", Node.Op("+", u, v), Node.Num("2")) end
		if k == -2 then return Node.Op("^", Node.Op("-", u, v), Node.Num("2")) end
	end

	return nil
end

return Tri