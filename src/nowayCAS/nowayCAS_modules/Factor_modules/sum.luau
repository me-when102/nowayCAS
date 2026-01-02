local H = require(script.Parent.helpers)
local Util = require(script.Parent.Parent.Util)
local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)

local Sum = {}

local table_insert = table.insert
local table_sort = table.sort

local ipairs = ipairs

-- factor a sum node by extracting the greatest common factor and
-- returning common * (sum of remainders); returns original node if no nontrivial factor.
function Sum.factorSum(node)

	if node.kind ~= "op" or node.op ~= "+" then
		return node
	end

	local terms = {}
	H.factor_flatten(node, "+", terms)
	if #terms < 2 then
		return node
	end

	local extracted = {}
	for _, t in ipairs(terms) do
		table_insert(extracted, H.extractTerm(t))
	end

	local factor = H.commonFactor(extracted)

	if factor.num == 1
		and next(factor.varExp) == nil
		and #factor.others == 0 then
		return node
	end

	local newTerms = {}
	for i, t in ipairs(extracted) do
		local remainder = {}
		remainder.num = t.num / factor.num
		remainder.varExp = {}
		for name, exp in pairs(t.varExp) do
			remainder.varExp[name] = exp - (factor.varExp[name] or 0)
		end
		remainder.others = {}
		for _, n in ipairs(t.others) do
			local remove = false
			for _, m in ipairs(factor.others) do
				if Util.nodeEquals(n, m) then
					remove = true
					break
				end
			end
			if not remove then
				table_insert(remainder.others, n)
			end
		end
		local mulNode = H.buildMul(remainder)
		table_insert(newTerms, Canon.canonical(mulNode))
	end

	table_sort(newTerms, function(a, b) return tostring(a) < tostring(b) end)

	local common = Canon.canonical(H.buildMul(factor))
	local distributed = Canon.canonical(H.buildAdd(newTerms))
	local product = Canon.canonical(Node.Op("*", common, distributed))

	-- ensure distributed side is a sum node for consistent comparisons
	if product.kind == "op" and product.op == "*" then
		local L, R = product.left, product.right
		if not (R.kind == "op" and R.op == "+") then
			R = Canon.canonical(Node.Op("+", R, Node.Num("0")))
			product = Canon.canonical(Node.Op("*", L, R))
		end
	end

	return product
end

return Sum