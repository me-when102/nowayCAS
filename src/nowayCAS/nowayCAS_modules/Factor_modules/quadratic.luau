local Node = require(script.Parent.Parent.Node)
local FactorHelpers = require(script.Parent.FactorHelpers)
local Util = require(script.Parent.Parent.Util)
local Simplify = require(script.Parent.Parent.Simplify)

local Quadratic = {}

-------------------------------------------------------
-- Quadratic
-------------------------------------------------------

-- Try to factor Av^2 + Bv + C in variable v
function Quadratic.factorQuadratic(node)
	if node.kind ~= "op" or node.op ~= "+" then
		return nil
	end

	-- Flatten sum
	local terms = {}
	FactorHelpers.factor_flatten(node, "+", terms)

	-- Detect variable with exponent 2
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

	-- Extract A, B, C
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

	-- Build the two linear factors directly:
	-- (A*v + p) * (v + q/A)
	-- But we avoid division by A by using grouping:
	--
	-- Av^2 + Bv + C = (A*v + p) * (v + q/A)
	-- and since p+q = B, this is valid.

	local vNode = Node.Var(var)

	local left  = Simplify.simplify(Node.Op("+", Node.Op("*", A, vNode), p))
	local right = Simplify.simplify(Node.Op("+", vNode, Node.Op("/", q, A)))

	return Node.Op("*", left, right)
end

return Quadratic