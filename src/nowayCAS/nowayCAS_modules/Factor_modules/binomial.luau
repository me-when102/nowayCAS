local H = require(script.Parent.helpers)
local Node = require(script.Parent.Parent.Node)
local Canon = require(script.Parent.Parent.Canon)
local Util = require(script.Parent.Parent.Util)

local Bin = {}

-- return true if node represents x^2 (a power with numeric exponent 2)
local function isSquareNode(n)
	return n and n.kind == "op" and n.op == "^"
		and n.right and n.right.kind == "num"
		and tonumber(n.right.value) == 2
end

-- attempt to factor a two-term (or flattened sum) node using
-- difference-of-square or perfect-square-trinomial patterns; return factored node
function Bin.factorBinomial(node)
	if node.kind ~= "op" or (node.op ~= "+" and node.op ~= "-") then
		return nil
	end

	local terms = {}
	if node.op == "-" then
		terms[1] = node.left
		terms[2] = node.right
	else
		H.factor_flatten(node, "+", terms)
	end

	local extractedList = {}
	for _, t in ipairs(terms) do
		table.insert(extractedList, { node = t, ex = H.extractTerm(t) })
	end

	-- difference of squares
	for i = 1, #extractedList do
		for j = i+1, #extractedList do
			local Ai, Aj = extractedList[i], extractedList[j]
			if isSquareNode(Ai.node) and isSquareNode(Aj.node) then
				local sign_i = Ai.ex.num < 0 and -1 or 1
				local sign_j = Aj.ex.num < 0 and -1 or 1
				if sign_i + sign_j == 0 then
					local u = Ai.node.left
					local v = Aj.node.left
					if sign_i < 0 then
						return Node.Op("*", Node.Op("-", v, u), Node.Op("+", v, u))
					else
						return Node.Op("*", Node.Op("-", u, v), Node.Op("+", u, v))
					end
				end
			end
		end
	end

	-- perfect square trinomial
	local squares = {}
	local crossCandidates = {}
	for _, item in ipairs(extractedList) do
		if isSquareNode(item.node) then
			table.insert(squares, item)
		else
			table.insert(crossCandidates, item)
		end
	end

	if #squares == 2 and #crossCandidates >= 1 then
		for _, crossItem in ipairs(crossCandidates) do
			local u = squares[1].node.left
			local v = squares[2].node.left
			local ex = crossItem.ex
			if math.abs(ex.num) == 2 then
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
					local inner = Node.Op(sign, u, v)
					return Node.Op("^", inner, Node.Num("2"))
				end
			end
		end
	end

	return nil
end

return Bin