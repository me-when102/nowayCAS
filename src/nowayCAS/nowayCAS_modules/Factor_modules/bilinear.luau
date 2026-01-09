local FactorHelpers = require(script.Parent.FactorHelpers)
local Sum = require(script.Parent.sum)
local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)
local Util = require(script.Parent.Parent.Util)
local Trace = require(script.Parent.trace)

local tostring = tostring
local pairs = pairs
local ipairs = ipairs

local table_sort = table.sort
local table_insert = table.insert

local Bil = {}

-------------------------------------------------------
-- Bilinear
-------------------------------------------------------

-- all ways to split 4 items into two pairs for grouping checks
local pairings = {
	{{1,2}, {3,4}},
	{{1,3}, {2,4}},
	{{1,4}, {2,3}},
}

-- try to factor a sum by finding a common factor across pairs for gruping checks
function Bil.factorByPairwiseCommon(node)
	if not (node and node.kind == "op" and node.op == "+") then return nil end

	-- Flatten and extract
	local terms = {}
	FactorHelpers.factor_flatten(node, "+", terms)
	if #terms < 2 then return nil end

	local extracted = {}
	for i, t in ipairs(terms) do
		extracted[i] = FactorHelpers.extractTerm(Canon.canonical(t))
		extracted[i].node = Canon.canonical(t)
	end

	-- Collect candidate factors from all pairs (use commonFactor logic)
	local candidateKeys = {}
	local candidateNodes = {}
	for i = 1, #extracted-1 do
		for j = i+1, #extracted do
			local cf = FactorHelpers.commonFactor({extracted[i], extracted[j]})
			-- ignore trivial factor (1)
			if not (cf.num == 1 and next(cf.varExp) == nil and #cf.others == 0) then
				local key = tostring(Canon.canonical(FactorHelpers.buildMul(cf)))
				candidateKeys[key] = cf
				candidateNodes[key] = Canon.canonical(FactorHelpers.buildMul(cf))
			end
		end
	end

	-- Score candidates by how many terms they divide
	local scored = {}
	for key, cf in pairs(candidateKeys) do
		local count = 0
		for _, ex in ipairs(extracted) do
			if FactorHelpers.factorDividesTerm(cf, ex) then count = count + 1 end
		end
		if count >= 2 then
			table_insert(scored, {key = key, factor = cf, node = candidateNodes[key], count = count})
		end
	end

	if #scored == 0 then return nil end

	-- Sort candidates by count desc, then by string length (prefer larger)
	table_sort(scored, function(a,b)
		if a.count ~= b.count then return a.count > b.count end
		return #a.key > #b.key
	end)

	-- Try each candidate: build remainders for terms it divides and assemble product
	for _, cand in ipairs(scored) do
		local Fdesc = cand.factor
		local Fnode = Canon.canonical(FactorHelpers.buildMul(Fdesc))

		local remainders = {}
		local usedIndices = {}
		for i, ex in ipairs(extracted) do
			if FactorHelpers.factorDividesTerm(Fdesc, ex) then
				local remDesc = FactorHelpers.divideTerm(ex, Fdesc)
				-- remove zero exponents
				for name, e in pairs(remDesc.varExp) do if e == 0 then remDesc.varExp[name] = nil end end
				table_insert(remainders, Canon.canonical(FactorHelpers.buildMul(remDesc)))
				usedIndices[i] = true
			end
		end

		-- require at least two terms used
		if #remainders >= 2 then
			local distributed = FactorHelpers.buildAdd(remainders)
			local product = Canon.canonical(Node.Op("*", Fnode, Canon.canonical(distributed)))

			-- If the product actually reduces the original (i.e., replacing used terms by product yields same canonical)
			-- Build new sum: replace used terms with product and keep others
			local newTerms = {}
			local inserted = false
			for i, t in ipairs(terms) do
				if usedIndices[i] then
					if not inserted then
						table_insert(newTerms, product)
						inserted = true
					end
				else
					table_insert(newTerms, Canon.canonical(t))
				end
			end
			local candidateSum = FactorHelpers.buildAdd(newTerms)
			-- canonical compare to ensure correctness
			if Util.nodeEquals(Canon.canonical(candidateSum), Canon.canonical(node)) then
				-- Optionally, try to see if multiple such factors share the same remainder (to assemble two-sided product)
				-- For now return the single product (it will be simplified further by bottom-up passes)
				return Canon.canonical(product)
			end
		end
	end

	return nil
end

-- attempt bilinear grouping on a 4-term sum, returning (F1+F2)*R if found.
function Bil.factorBilinearGrouping(node)
	if node.kind ~= "op" or node.op ~= "+" then
		return nil 
	end

	-- flatten and canonicalize the 4 terms once
	local terms = {}
	FactorHelpers.factor_flatten(node, "+", terms)
	if #terms ~= 4 then
		return nil 
	end

	-- canonicalize each term to remove ordering differences
	local canonTerms = {}
	for i, t in ipairs(terms) do
		canonTerms[i] = Canon.canonical(t)
	end

	-- all pairings of 4 terms into two pairs
	local pairings = {
		{{1,2}, {3,4}},
		{{1,3}, {2,4}},
		{{1,4}, {2,3}},
	}

	-- factor a canonical pair and return canonical factor F and canonical normalized remainder R
	local function tryFactorPairFromCanon(i, j)
		local pairNode = Node.Op("+", canonTerms[i], canonTerms[j])
		local canonPair = Canon.canonical(pairNode)

		-- Factor the canonical pair
		local factored = Sum.factorSum(canonPair)
		local canonFactored = Canon.canonical(factored)

		Trace.log("PAIR_CANON:", tostring(canonPair))
		Trace.log("FACTORED_CANON:", tostring(canonFactored))

		-- If factoring didn't change the canonical form, nothing happened
		if tostring(canonFactored) == tostring(canonPair) then
			return nil, nil
		end

		if canonFactored.kind == "op" and canonFactored.op == "*" then
			local F, R = canonFactored.left, canonFactored.right
			-- prefer non-sum side as F
			if F.kind == "op" and F.op == "+" then
				F, R = canonFactored.right, canonFactored.left
			end
			F = Canon.canonical(F)
			-- normalize remainder to be a sum node
			if not (R.kind == "op" and R.op == "+") then
				R = Canon.canonical(Node.Op("+", R, Node.Num("0")))
			else
				R = Canon.canonical(R)
			end
			return F, R
		end

		return nil, nil
	end

	-- canonical equality check for nodes
	local function equalsCanonical(a, b)
		if a == b then return true end
		if not a or not b then return a == b end
		local ca = Canon.canonical(a)
		local cb = Canon.canonical(b)
		return tostring(ca) == tostring(cb)
	end

	-- try each pairing
	for _, p in ipairs(pairings) do
		local i1, j1 = p[1][1], p[1][2]
		local i2, j2 = p[2][1], p[2][2]

		local F1, R1 = tryFactorPairFromCanon(i1, j1)
		local F2, R2 = tryFactorPairFromCanon(i2, j2)

		if Trace.enabled then
			Trace.log(("Pairing (%d,%d) vs (%d,%d) -> F1=%s R1=%s | F2=%s R2=%s")
				:format(i1, j1, i2, j2, tostring(F1), tostring(R1), tostring(F2), tostring(R2)))
		end

		local equal = equalsCanonical(R1, R2)
		if F1 and F2 and equal then
			local leftSum = Canon.canonical(Node.Op("+", F1, F2))
			local result = Canon.canonical(Node.Op("*", leftSum, R1))
			return result
		end
	end

	return nil
end

return Bil