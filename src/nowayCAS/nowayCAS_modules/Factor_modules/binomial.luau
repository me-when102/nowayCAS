local FactorHelpers = require(script.Parent.FactorHelpers)
local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)
local Simplify = require(script.Parent.Parent.Simplify)
local Util = require(script.Parent.Parent.Util)

local tonumber = tonumber
local ipairs = ipairs
local table_insert = table.insert

local Bin = {}

-------------------------------------------------------
-- Binomial
-------------------------------------------------------

-- Build (u - v)(u + v)
local function diffOfSquares(u, v)
	return Canon.canonical(
		Node.Op("*",
			Node.Op("-", u, v),
			Node.Op("+", u, v)
		)
	)
end

-- Build (u +- v)^2
local function perfectSquare(u, v, sign)
	local inner
	if sign == "+" then
		inner = Node.Op("+", u, v)
	else
		-- normalise -(u) + v -> (v - u)
		inner = Node.Op("-", u, v)
	end

	return Canon.canonical(Node.Op("^", inner, Node.Num("2")))
end

-- Factorizes the node in binomial if possible.
function Bin.factorBinomial(node)
	-- Only sums or differences can be binomials/trinomials
	if not Util.isOp(node) or (node.op ~= "+" and node.op ~= "-") then
		return nil
	end

	-- Flatten into terms
	local terms = {}
	if node.op == "-" then
		terms[1] = node.left
		terms[2] = Node.Op("*", Node.Num("-1"), node.right)
	else
		FactorHelpers.factor_flatten(node, "+", terms)
	end

	-- Extract square bases
	local squareTerms = {}
	local others = {}

	for _, t in ipairs(terms) do
		local isSq, base, sign = FactorHelpers.getSquareBaseSigned(t)
		if isSq then
			table_insert(squareTerms, { node = t, base = base, sign = sign })
		else
			table_insert(others, t)
		end
	end

	-- Difference of squares: exactly 2 terms, both squares
	if #terms == 2 and #squareTerms == 2 then
		local A = squareTerms[1]
		local B = squareTerms[2]

		-- Check signs via extracted term
		local exA = FactorHelpers.extractTerm(A.node)
		local exB = FactorHelpers.extractTerm(B.node)

		-- We want A - B or B - A
		if exA.num > 0 and exB.num < 0 then
			return diffOfSquares(A.base, B.base)
		elseif exA.num < 0 and exB.num > 0 then
			return diffOfSquares(B.base, A.base)
		end
	end

	-- Perfect square trinomial: (U^2) +- 2UV + (V^2)
	if #terms == 3 and #squareTerms == 2 and #others == 1 then
		local u = squareTerms[1].base
		local v = squareTerms[2].base
		local mid = others[1]

		-- reject if u or v are not simple monomials (no numeric sqrt, no products)
		if not FactorHelpers.isSimpleMonomial(u) then return nil end 
		if not FactorHelpers.isSimpleMonomial(v) then return nil end

		-- Compute mid / (u*v)
		local uv = Node.Op("*", u, v)
		local ratio = Simplify.simplify(Node.Op("/", mid, uv))

		-- ratio must simplify to +2 or -2
		if Util.isNum(ratio) then
			local k = tonumber(ratio.value)
			if k == 2 or k == -2 then
				local sign = (k == 2) and "+" or "-"
				return perfectSquare(u, v, sign)
			end
		end
	end

	return nil
end

return Bin