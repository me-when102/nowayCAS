local H = require(script.Parent.helpers)
local Util = require(script.Parent.Parent.Util)
local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)

local Sum = {}

local table_insert = table.insert
local table_sort = table.sort
local ipairs = ipairs

-------------------------------------------------------
-- Sum
-- Extracts the greatest common factor from a sum.
-- Returns the original node if no nontrivial factor exists.
-------------------------------------------------------

function Sum.factorSum(node)
	-- Only sums can be factored here
	if node.kind ~= "op" or node.op ~= "+" then
		return node
	end

	-- Flatten the sum
	local terms = {}
	H.factor_flatten(node, "+", terms)
	if #terms < 2 then
		return node
	end

	-- Extract term descriptors
	local extracted = {}
	for _, t in ipairs(terms) do
		table_insert(extracted, H.extractTerm(t))
	end

	-- Compute the greatest common factor
	local factor = H.commonFactor(extracted)

	-- If factor is trivial, return original
	if factor.num == 1
		and next(factor.varExp) == nil
		and #factor.others == 0 then
		return node
	end

	-- Build remainders
	local newTerms = {}

	for _, t in ipairs(extracted) do
		local remainder = {
			num = t.num / factor.num,
			varExp = {},
			others = {}
		}

		-- subtract exponents
		for name, exp in pairs(t.varExp) do
			local newExp = exp - (factor.varExp[name] or 0)
			if newExp ~= 0 then
				remainder.varExp[name] = newExp
			end
		end

		-- remove matching "others"
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

		local mulNode = Canon.canonical(H.buildMul(remainder))
		table_insert(newTerms, mulNode)
	end

	-- Build final product: common * (sum of remainders)
	local common = Canon.canonical(H.buildMul(factor))
	local distributed = Canon.canonical(H.buildAdd(newTerms))

	local product = Canon.canonical(Node.Op("*", common, distributed))

	-- Ensure right side is a sum node
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