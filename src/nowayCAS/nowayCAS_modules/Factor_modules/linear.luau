local H = require(script.Parent.helpers)
local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)
local Rewrite = require(script.Parent.Parent.Rewrite)
local Rules = require(script.Parent.Parent.Rewrite.Rules)
local Util = require(script.Parent.Parent.Util)
local Simplify = require(script.Parent.Parent.Simplify)

local Lin = {}

-- create a left-associative sum Node from an arry of nodes (returns 0 if empty)
local function buildAdd(nodes)
	if #nodes == 0 then return Node.Num("0") end
	local acc = nodes[1]
	for i = 2, #nodes do acc = Node.Op("+", acc, nodes[i]) end
	return acc
end

-- if node is linear in varName, return A*(varName + Q) candidate, else nil
function Lin.factorLinearIn(node, varName)
	if node.kind ~= "op" or node.op ~= "+" then return nil end

	local terms = {}
	H.factor_flatten(node, "+", terms)

	local A_terms = {}
	local B_terms = {}

	for _, t in ipairs(terms) do
		local extracted = H.extractTerm(t)
		local exp = extracted.varExp[varName] or 0
		if exp > 1 then return nil end
		if exp == 1 then
			local newVarExp = {}
			for k,v in pairs(extracted.varExp) do
				if k ~= varName then newVarExp[k] = v end
			end
			table.insert(A_terms, { num = extracted.num, varExp = newVarExp, others = extracted.others })
		else
			table.insert(B_terms, extracted)
		end
	end

	if #A_terms == 0 then return nil end

	local function buildPoly(terms)
		local nodes = {}
		for _, t in ipairs(terms) do table.insert(nodes, H.buildMul(t)) end
		return buildAdd(nodes)
	end

	local A = buildPoly(A_terms)
	local B = buildPoly(B_terms)

	local Q = Node.Op("/", B, A)
	Q = Simplify.simplify(Q)

	local candidate = Node.Op("*", A, Node.Op("+", Node.Var(varName), Q))
	local expanded = Rewrite.apply(candidate, Rules.expandRules)
	expanded = Canon.canonical(expanded)
	local original = Canon.canonical(node)

	if Util.nodeEquals(expanded, original) then
		return candidate
	end

	return nil
end

return Lin