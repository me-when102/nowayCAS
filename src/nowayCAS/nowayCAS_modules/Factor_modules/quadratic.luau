local Node = require(script.Parent.Parent.Node)
local FactorHelpers = require(script.Parent.FactorHelpers)
local Util = require(script.Parent.Parent.Util)
local Simplify = require(script.Parent.Parent.Simplify)
local Bin = require(script.Parent.binomial)

local Quadratic = {}

-------------------------------------------------------
-- Quadratic
-------------------------------------------------------

-- Detect whether n is a perfect square integer (possibly negative).
-- Returns (true, base, sign) where:
--   base = Node.Num(sqrt(|n|))
--   sign = +1 or -1
-- Only used for discriminant checking.
local function getSquareBaseSigned(n)
    if not Util.isNum(n) then
        return false, nil, nil
    end

    local v = tonumber(n.value)
    if not v then
        return false, nil, nil
    end

    local absV = math.abs(v)
    local r = math.sqrt(absV)

    if r ~= math.floor(r) then
        return false, nil, nil
    end

    local base = Node.Num(tostring(r))
    local sign = (v >= 0) and 1 or -1
    return true, base, sign
end

-- Try to factor Av^2 + Bv + C in variable v
function Quadratic.factorQuadratic(node)
    if not (Util.isOp(node) and node.op == "+") then
        return nil
    end

    -- Flatten sum
    local terms = {}
    FactorHelpers.factor_flatten(node, "+", terms)

    -- Detect variable with exponent 2 (we allow other vars in coefficients)
    local var = nil
    for _, t in ipairs(terms) do
        local ex = FactorHelpers.extractTerm(t)
        for name, exp in pairs(ex.varExp) do
            if exp == 2 then
                var = name
            end
        end
    end
    if not var then
        return nil
    end

    -- Extract A, B, C as expressions
    local A = Node.Num("0")
    local B = Node.Num("0")
    local C = Node.Num("0")

    for _, t in ipairs(terms) do
        local ex = FactorHelpers.extractTerm(t)
        local exp = ex.varExp[var] or 0

        if exp == 2 then
            A = Node.Op("+", A, FactorHelpers.removeVarPower(t, var, 2))
        elseif exp == 1 then
            B = Node.Op("+", B, FactorHelpers.removeVarPower(t, var, 1))
        else
            C = Node.Op("+", C, t)
        end
    end

    A = Simplify.simplify(A)
    B = Simplify.simplify(B)
    C = Simplify.simplify(C)

    -- Compute discriminant Δ = B^2 - 4AC
    local disc = Simplify.simplify(
        Node.Op("-",
            Node.Op("^", B, Node.Num("2")),
            Node.Op("*", Node.Num("4"), Node.Op("*", A, C))
        )
    )

    -- Only factor if discriminant is a perfect square integer
    local isSq, _, sign = getSquareBaseSigned(disc)
    if not isSq or sign < 0 then
        return nil
    end

    -- Perfect square case: let binomial module own it
    -- TODO: removing this breaks factorization (quadratic needs more fixing)
    if Util.isNum(disc) and tonumber(disc.value) == 0 then
        return Bin.factorBinomial(node)
    end

    -- AC method: find p,q such that p*q = A*C and p+q = B
    local AC = Simplify.simplify(Node.Op("*", A, C))

    local function trySplit()
        local facs = FactorHelpers.factorPairs(AC)
        for _, pair in ipairs(facs) do
            local p, q = pair[1], pair[2]
            if Util.nodeEquals(Simplify.simplify(Node.Op("+", p, q)), B) then
                return p, q
            end
        end
        return nil
    end

    local p, q = trySplit()
    if not p then
        return nil
    end

    -- Factor by grouping:
    -- A v^2 + B v + C = A v^2 + p v + q v + C
    local vNode = Node.Var(var)

    local pTerm = Node.Op("*", p, vNode)
    local qTerm = Node.Op("*", q, vNode)

    -- Factor each group using common factors
    local g1 = FactorHelpers.commonFactor({
        FactorHelpers.extractTerm(Node.Op("*", A, vNode)),
        FactorHelpers.extractTerm(pTerm),
    })

    local g2 = FactorHelpers.commonFactor({
        FactorHelpers.extractTerm(qTerm),
        FactorHelpers.extractTerm(C),
    })

    local left  = FactorHelpers.buildMul(g1)
    local right = FactorHelpers.buildMul(g2)

    return Node.Op("*", left, right)
end

return Quadratic