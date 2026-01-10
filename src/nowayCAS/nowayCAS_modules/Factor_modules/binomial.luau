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

-- Detect n = +-(K * U^2) where K is a perfect square (possibly 1),
-- returning (true, base, sign), where base is K^(1/2) * U and sign is +-1.
local function getSquareBaseSigned(n)
	-- pure symbolic square: u^2
	if n.kind == "op" and n.op == "^" then
		if n.right.kind == "num" and tonumber(n.right.value) == 2 then
			return true, n.left, 1
		end
	end

	-- pure numeric square: +-k
	if n.kind == "num" then
		local v = tonumber(n.value)
		if v then
			local r = math.sqrt(math.abs(v))
			if r == math.floor(r) then
				local base = Node.Num(tostring(r))
				local sign = (v >= 0) and 1 or -1
				return true, base, sign
			end
		end
	end

	-- general monomial with coefficient and powers, e.g. 9x^2, -25y^2, 49a^2
	-- Use FactorHelpers.extractTerm to pull out numeric coefficient and symbolic factors.
	local ex = FactorHelpers.extractTerm(n)
	-- ex.num: integer coefficient
	-- ex.varExp: map name -> exponent
	-- ex.others: list of non-var/const factors

	-- We only handle pure monomials: no "others"
	if #ex.others > 0 then
		return false, nil, nil
	end

	-- All exponents must be even to be a square
	for _, exp in pairs(ex.varExp) do
		if exp % 2 ~= 0 then
			return false, nil, nil
		end
	end

	-- Coefficient must be a perfect square up to sign
	local coeff = ex.num
	if coeff == 0 then
		-- 0 is a square: 0^2
		return true, Node.Num("0"), 1
	end

	local sign = (coeff >= 0) and 1 or -1
	local absCoeff = math.abs(coeff)
	local r = math.sqrt(absCoeff)
	if r ~= math.floor(r) then
		return false, nil, nil
	end

	-- Build base = r * Π var^(exp/2)
	local factors = {}

	-- numeric part
	if r ~= 1 then
		table_insert(factors, Node.Num(tostring(r)))
	end

	-- symbolic part: each var^(exp/2)
	for name, exp in pairs(ex.varExp) do
		local half = exp // 2
		local base
		if name:sub(1,6) == "const:" then
			base = Node.Const(name:sub(7))
		else
			base = Node.Var(name)
		end

		if half == 1 then
			table_insert(factors, base)
		else
			table_insert(factors, Node.Op("^", base, Node.Num(tostring(half))))
		end
	end

	-- If no symbolic factors and r == 1, it's just 1
	if #factors == 0 then
		table_insert(factors, Node.Num("1"))
	end

	-- Fold factors into a product or single node
	local baseNode = factors[1]
	for i = 2, #factors do
		baseNode = Node.Op("*", baseNode, factors[i])
	end

	return true, baseNode, sign
end

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
    if node.kind ~= "op" or (node.op ~= "+" and node.op ~= "-") then
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
		local isSq, base, sign = getSquareBaseSigned(t)
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
		if ratio.kind == "num" then
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