local StructuralCanon = {}

local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)
local CanonAlgebraHelpers = require(script.Parent.CanonAlgebraHelpers)
local CanonHelpers = require(script.Parent.CanonHelpers)

-- Canonicalizes the node structurally.
function StructuralCanon.normalize(node)
	if Util.isNum(node) or Util.isVar(node) or Util.isConst(node) then
		return node
	end

	if Util.isFunc(node) then
		return StructuralCanon.normalizeFunc(node)

	elseif Util.isComplex(node) then
		return StructuralCanon.normalizeComplex(node)

	elseif Util.isOp(node) then
		return StructuralCanon.normalizeOp(node)

	elseif Util.isRat(node) then
		return StructuralCanon.normalizeRat(node)

	elseif Util.isPiecewise(node) then
		return StructuralCanon.normalizePiecewise(node)

	end

	error("StructuralCanon: unknown node kind '" .. tostring(node.kind) .. "'")
end

-- Canonicalizes the operator node structurally.
function StructuralCanon.normalizeOp(node)
	local op = node.op
	local left = StructuralCanon.normalize(node.left)
	local right = StructuralCanon.normalize(node.right)

	-- ADDITION
	if op == "+" then
		local items = CanonAlgebraHelpers.flatten("+", { left, right })

		table.sort(items, function(a, b)
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		if #items == 0 then return Node.Num("0") end
		if #items == 1 then return items[1] end

		local acc = items[1]
		for i = 2, #items do
			acc = Node.Op("+", acc, items[i])
		end
		return acc
	end

	-- MULTIPLICATION
	if op == "*" then
		local items = CanonAlgebraHelpers.flatten("*", { left, right })

		table.sort(items, function(a, b)
			if Util.isNum(a) and not Util.isNum(b) then return true end
			if Util.isNum(b) and not Util.isNum(a) then return false end
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		if #items == 1 then return items[1] end

		local acc = items[1]
		for i = 2, #items do
			acc = Node.Op("*", acc, items[i])
		end
		return acc
	end

	-- LOGICAL OPERATORS
	if op == "and" or op == "or" then
		local items = CanonAlgebraHelpers.flatten(op, { left, right })

		local seen = {}
		local unique = {}
		for _, n in ipairs(items) do
			local key = CanonHelpers.canonicalKey(n)
			if not seen[key] then
				seen[key] = true
				table.insert(unique, n)
			end
		end

		table.sort(unique, function(a, b)
			return CanonHelpers.canonicalKey(a) < CanonHelpers.canonicalKey(b)
		end)

		if #unique == 1 then return unique[1] end

		local acc = unique[1]
		for i = 2, #unique do
			acc = Node.Op(op, acc, unique[i])
		end
		return acc
	end

	-- Fallback, rebuild the node.
	return Node.Op(op, left, right)
end

-- Normalizes the function node structurally.
function StructuralCanon.normalizeFunc(node)
	-- Canonicalize each argument structurally
	local newArgs = {}
	for i, a in ipairs(node.args) do
		newArgs[i] = StructuralCanon.normalize(a)
	end

	local name = node.name

	-- Fallback, rebuild the node.
	return Node.Func(name, newArgs)
end

-- Normalizes the complex node structurally.
function StructuralCanon.normalizeComplex(node)
	local real = StructuralCanon.normalize(node.real)
	local imag = StructuralCanon.normalize(node.imag)

	-- StructuralCanon does NOT collapse or simplify
	return Node.Complex(real, imag)
end

-- Normalizes the rational node structurally.
function StructuralCanon.normalizeRat(node)
	-- Rationals have no structural normalization
	return node
end

-- Normalizes the piecewise function structurally.
function StructuralCanon.normalizePiecewise(node)

	local function distribute(cond, expr)
		if not Util.isPiecewise(expr) then
			return { { cond, expr } }
		end

		local out = {}
		for _, inner in ipairs(expr.branches) do
			local innerCond = inner[1]
			local innerExpr = inner[2]

			-- newCond = cond AND innerCond
			local newCond = Node.Op("and", cond, innerCond)
			newCond = StructuralCanon.normalize(newCond)

			table.insert(out, { newCond, innerExpr })
		end
		return out
	end

	local newBranches = {}

	for _, pair in ipairs(node.branches) do
		local cond = StructuralCanon.normalize(pair[1])
		local expr = StructuralCanon.normalize(pair[2])

		local expanded = distribute(cond, expr)
		for _, b in ipairs(expanded) do
			table.insert(newBranches, b)
		end
	end

	return Node.Piecewise(newBranches)
end

return StructuralCanon