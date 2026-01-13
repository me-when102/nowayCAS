local FactorHelpers = require(script.Parent.FactorHelpers)
local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)
local Rewrite = require(script.Parent.Parent.Rewrite)
local Expand = require(script.Parent.Parent.Expand)
local Util = require(script.Parent.Parent.Util)
local Simplify = require(script.Parent.Parent.Simplify)

local tonumber = tonumber
local ipairs = ipairs
local table_insert = table.insert

local Lin = {}

-------------------------------------------------------
-- Linear
-------------------------------------------------------

-- Creates the nodes wrapped under a sum node.
local function buildAdd(nodes)
	if #nodes == 0 then return Node.Num("0") end
	local acc = nodes[1]
	for i = 2, #nodes do
		acc = Node.Op("+", acc, nodes[i])
	end
	return acc
end

-- Negates the node.
local function negate(n)
	return Node.Op("*", Node.Num("-1"), n)
end

-- Factorizes the node in linear if possible.
function Lin.factorLinearIn(node, varName)
	if not (Util.isOp(node) and node.op == "+") then
		return nil
	end

	-- Split into A_terms (contain varName) and B_terms (do not)
	local terms = {}
	FactorHelpers.factor_flatten(node, "+", terms)

	local A_terms = {}
	local B_terms = {}

	for _, t in ipairs(terms) do
		local ex = FactorHelpers.extractTerm(t)
		local exp = ex.varExp[varName] or 0

		-- Nonlinear -> abort
		if exp > 1 then
			return nil
		end

		if exp == 1 then
			-- Remove varName from exponent map
			local newVarExp = {}
			for k, v in pairs(ex.varExp) do
				if k ~= varName then
					newVarExp[k] = v
				end
			end
			table_insert(A_terms, {
				num = ex.num,
				varExp = newVarExp,
				others = ex.others
			})
		else
			table_insert(B_terms, ex)
		end
	end

	-- No linear terms -> not linear
	if #A_terms == 0 then
		return nil
	end

	-- Build A and B polynomials
	local function buildPoly(list)
		local nodes = {}
		for _, t in ipairs(list) do
			table_insert(nodes, FactorHelpers.buildMul(t))
		end
		return buildAdd(nodes)
	end

	local A = Canon.canonical(buildPoly(A_terms))
	local B = Canon.canonical(buildPoly(B_terms))

	-- Heuristic: avoid trivial or ugly factorizations

	-- Reject A = +-1
	if Util.isOne(A) or Util.isNegOne(A) then
		return nil
	end

	-- Reject A being a sum (optional heuristic for cleaner output)
	if Util.isOp(A) and A.op == "+" then
		return nil
	end

	-- Compute Q = B / A
	local Q = Canon.canonical(Node.Op("/", B, A))
	Q = Simplify.simplify(Q)

	-- Normalize sign: ensure A is positive
	if Util.isNegOne(A) or (Util.isNum(A) and tonumber(A.value) < 0) then
		A = Canon.canonical(negate(A))
		Q = Canon.canonical(negate(Q))
	end

	-- Build candidate: A * (varName + Q)
	local varNode = Util.buildSymbol(varName)
	local inner = Node.Op("+", varNode, Q)
	local candidate = Node.Op("*", A, inner)

	-- Verify correctness by expansion
	local expanded = Expand.expand(candidate)
	expanded = Canon.canonical(expanded)

	local original = Canon.canonical(node)

	if Util.nodeEquals(expanded, original) then
		return Canon.canonical(candidate)
	end

	return nil
end

return Lin