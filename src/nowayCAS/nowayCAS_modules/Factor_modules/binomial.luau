local FactorHelpers = require(script.Parent.FactorHelpers)
local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)
local Util = require(script.Parent.Parent.Util)

local tonumber = tonumber
local ipairs = ipairs
local table_insert = table.insert

local Bin = {}

-------------------------------------------------------
-- Binomial
-------------------------------------------------------

-- Detect n = +-u^2, returning (true, u, sign)
local function getSquareBaseSigned(n)
	-- symbolic square: u^2
	if n.kind == "op" and n.op == "^" then
		if n.right.kind == "num" and tonumber(n.right.value) == 2 then
			return true, n.left, 1
		end
	end

	-- numeric square: +-k
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

	return false, nil, nil
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
    local inner = Node.Op(sign, u, v)
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

    -- Perfect square trinomial: exactly 3 terms
    if #terms == 3 and #squareTerms == 2 and #others == 1 then
        local u = squareTerms[1].base
        local v = squareTerms[2].base
        local mid = others[1]

        local ex = FactorHelpers.extractTerm(mid)

        -- coefficient must be +-2
        if math.abs(ex.num) == 2 then
            -- Check mid term contains exactly u and v once
            local ok = false

            if u.kind == "var" and v.kind == "var" then
                ok = (ex.varExp[u.name] == 1) and (ex.varExp[v.name] == 1)
            else
                local foundU, foundV = false, false
                for _, o in ipairs(ex.others) do
                    if Util.nodeEquals(o, u) then foundU = true end
                    if Util.nodeEquals(o, v) then foundV = true end
                end
                ok = foundU and foundV
            end

            if ok then
                local sign = (ex.num > 0) and "+" or "-"
                return perfectSquare(u, v, sign)
            end
        end
    end

    return nil
end

return Bin