local Factor = {}

-------------------------------------------------------
-- Factor
-- Facorizes expressions.
-- May be one of the advanced + difficult modules in here
-------------------------------------------------------
-- TODO: 
-- Fix generalized binomial factorization (Difficulty: Hard)

local Canon = require(script.Parent.Canon)
local Simplify = require(script.Parent.Simplify)
local Util = require(script.Parent.Util)
local Node = require(script.Parent.Node)

local H = require(script.helpers)
local Sum = require(script.sum)
local Bil = require(script.bilinear)
local Bin = require(script.binomial)
local Lin = require(script.linear)
local Trace = require(script.trace)

-- expose trace toggle
Factor.trace = Trace

-- recursively apply f bottom-up to every node and return f(node)
local function mapNode(node, f)
	if node.kind == "op" then
		local left = mapNode(node.left, f)
		local right = mapNode(node.right, f)
		node = Node.Op(node.op, left, right)
	end
	local replaced = f(node)
	return replaced
end

-- try binomial, bilinear, linear-in-var, then sum fallback at this node
local function factorAt(node)
	-- binomial first
	local b = Bin.factorBinomial(node)
	Trace.log("Binomial attempt: ".. tostring(b))
	if b then return b end

	-- bilinear grouping
	local bil = Bil.factorBilinearGrouping(node)
	Trace.log("Bilinear Grouping attempt: ".. tostring(bil))
	if bil then return bil end
	
	-- linear in variable
	if node.kind == "op" and node.op == "+" then
		local vars = {}
		local terms = {}
		H.factor_flatten(node, "+", terms)
		for _, t in ipairs(terms) do
			local ex = H.extractTerm(t)
			for name in pairs(ex.varExp) do vars[name] = true end
		end
		for name in pairs(vars) do
			local lin = Lin.factorLinearIn(node, name)
			if lin then return lin end
		end
	end

	-- fallback
	if node.kind == "op" and node.op == "+" then
		return Sum.factorSum(node)
	end

	return node
end

-- attempt f at node before recursing, preserve sums for recursion
local function mapNodeTopDown(node, f)
	-- Try transform at this node first
	local replaced = f(node)
	if replaced and not (replaced.kind == "op" and replaced.op == "+") then
		-- If f returned a non-nil transformation, use it (no recursion)
		return replaced
	end

	-- Otherwise recurse into children (preserve replaced if it's still a sum)
	if node.kind == "op" then
		local left = mapNodeTopDown(node.left, f)
		local right = mapNodeTopDown(node.right, f)
		node = Node.Op(node.op, left, right)
	end

	-- Try f again after recursing (optional; keep bottom-up behavior)
	local after = f(node)
	return after or node
end

-- Factorizes the node.
-- Canonicalize, try pariwse common, top-down bilinear pass, then iterative bottom-up factoring loop.
function Factor.factor(node)
	node = Canon.canonical(node)
	
	local common = Bil.factorByPairwiseCommon(node)
	if common then return common end

	-- One top-down pass to catch 4-term groupings before children are changed
	node = mapNodeTopDown(node, function(n)
		-- only attempt bilinear grouping here
		return Bil.factorBilinearGrouping(n)
	end)
	node = Canon.canonical(node)

	-- existing bottom-up iterative loop
	local prev
	repeat
		prev = node
		node = mapNode(node, factorAt)
		node = Simplify.simplify(node)
		node = Canon.canonical(node)
	until Util.nodeEquals(node, prev)

	node = Canon.canonical(node)
	return node
end

return Factor