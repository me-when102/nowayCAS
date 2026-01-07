local Rewrite = {}

local Node = require(script.Parent.Node)
local Canon = require(script.Parent.Canon)
local Util = require(script.Parent.Util)
local DSL = require(script.DSL)

local table_remove = table.remove
local table_insert = table.insert

local ipairs = ipairs

-------------------------------------------------------
-- Rewrite
-------------------------------------------------------

local OpInfo = {
	["+"] = { assoc = true, comm = true },
	["*"] = { assoc = true, comm = true },
	["-"] = { assoc = false, comm = false },
	["/"] = { assoc = false, comm = false },
}

-- Checks if the node's operator is op.
local function isAssocOp(node, op)
	return node.kind == "op" and node.op == op
end

-- Gets the children of the node (left and right).
local function childrenOf(node, op)
	if isAssocOp(node, op) then
		local items = {}
		local function collect(n)
			if isAssocOp(n, op) then
				collect(n.left); collect(n.right)
			else
				table_insert(items, n)
			end
		end
		collect(node)
		return items
	else
		return { node }
	end
end

-- Try to apply one rule to a node
function Rewrite._applyRule(node, rule)
	local bindings = Rewrite._match(rule.pattern, node)
	if not bindings then
		return node, false
	end

	local next = rule.replace(node, bindings)

	-- Prevent false "changed" signals
	if Util.nodeEquals(next, node) then
		return node, false
	end

	return next, true
end

-- Try all rules once
function Rewrite._rewrite(node, rules)
	-- Recurse first
	if node.kind == "op" then
		local left, changedL = Rewrite._rewrite(node.left, rules)
		local right, changedR = Rewrite._rewrite(node.right, rules)
		if changedL or changedR then
			node = Node.Op(node.op, left, right)
		end
	elseif node.kind == "func" then
		local newArgs = {}
		local changed = false
		for i, arg in ipairs(node.args) do
			local nextArg, argChanged = Rewrite._rewrite(arg, rules)
			newArgs[i] = nextArg
			changed = changed or argChanged
		end
		if changed then
			node = Node.Func(node.name, newArgs)
		end
	end

	-- Then try rules at this node
	for _, rule in ipairs(rules) do
		local next, changed = Rewrite._applyRule(node, rule)
		if changed then
			return next, true
		end
	end

	return node, false
end

-- Performs a rewrite on a node with a set of rules.
function Rewrite.apply(node, rules)
	while true do
		local next, changed = Rewrite._rewrite(node, rules)
		if not changed then
			return Canon.canonical(node)
		end
		node = next
	end
	return node
end

-------------------------------------------------------
-- Pattern-matching system
-------------------------------------------------------

-- Checks if the name is a wildcard (starts with "_")
local function isWildcardName(name)
	return name:match("^_") ~= nil
end

-- Classify single-node wildcard by suffix
local function classifySingleWildcard(name)
	-- _n  -> numeric
	-- _v  -> variable
	-- _x  -> any
	if name == "_n" then
		return "num"
	elseif name == "_v" then
		return "var"
	else
		-- default: any
		return "any"
	end
end

-- Classify sequence wildcard by suffix
local function classifySeqWildcard(name)
	-- _ns -> numeric sequence
	-- _vs -> variable sequence
	-- _xs -> any sequence
	if name == "_ns" then
		return "num"
	elseif name == "_vs" then
		return "var"
	else
		-- default: any
		return "any"
	end
end

-- Checks if the wildcard is a sequence
local function isSeqWildcard(pattern)
	return pattern.kind == "var"
		and isWildcardName(pattern.name)
		and pattern.name:match("s$") -- ends with s
end

-- Match the multi-set
function Rewrite._matchMultiset(pList, nList, bindings)
	if #pList == 0 and #nList == 0 then
		return bindings
	end

	local p = pList[1]

	for i = 1, #nList do
		local n = nList[i]

		local newBindings = Rewrite._match(p, n, table.clone(bindings))
		if newBindings then
			-- remove matched element
			local remainingN = table.clone(nList)
			table_remove(remainingN, i)

			local remainingP = table.clone(pList)
			table_remove(remainingP, 1)

			local result = Rewrite._matchMultiset(remainingP, remainingN, newBindings)
			if result then return result end
		end
	end

	return nil
end

-- Finds the sequence of the wildcard.
local function findSeqWildcard(list)
	for i, p in ipairs(list) do
		if p.kind == "var" and isSeqWildcard(p) then
			return i, p
		end
	end
	return nil
end

-- Matches Associative-Commutative operators in a sequence
function Rewrite._matchACSeq(pattern, node, bindings)
	local pChildren = childrenOf(pattern, pattern.op)
	local nChildren = childrenOf(node, node.op)

	-- Find the sequence wildcard
	local seqIndex, seqPat = findSeqWildcard(pChildren)
	if not seqIndex then
		return nil
	end

	local seqKind = classifySeqWildcard(seqPat.name)

	-- Remove the sequence wildcard from the pattern list
	local fixedP = table.clone(pChildren)
	table_remove(fixedP, seqIndex)

	-- We must match all fixed pattern children against some subset of nChildren
	-- Use backtracking to choose which nChildren correspond to fixedP
	local function backtrack(pList, nList, currentBindings)
		if #pList == 0 then
			-- Everything else goes to the sequence wildcard
			local slice = {}

			for _, n in ipairs(nList) do
				if seqKind == "num" and not (n.kind == "num" or n.kind == "rat") then
					return nil
				elseif seqKind == "var" and n.kind ~= "var" then
					return nil
				end
				table_insert(slice, n)
			end

			local key = seqPat.name
			if currentBindings[key] then
				if not Util.nodeListEquals(currentBindings[key], slice) then
					return nil
				end
			else
				currentBindings[key] = slice
			end

			return currentBindings
		end

		local p = pList[1]

		for i = 1, #nList do
			local n = nList[i]

			local newBindings = Rewrite._match(p, n, table.clone(currentBindings))
			if newBindings then
				local remainingN = table.clone(nList)
				table_remove(remainingN, i)

				local remainingP = table.clone(pList)
				table_remove(remainingP, 1)

				local result = backtrack(remainingP, remainingN, newBindings)
				if result then return result end
			end
		end

		return nil
	end

	return backtrack(fixedP, nChildren, bindings)
end

-- Match Associative and Commutative operators
function Rewrite._matchAC(pattern, node, bindings)
	local pChildren = childrenOf(pattern, pattern.op)
	local nChildren = childrenOf(node, node.op)

	-- Check for sequence wildcard
	local seqIndex = findSeqWildcard(pChildren)
	if seqIndex then
		return Rewrite._matchACSeq(pattern, node, bindings)
	end

	-- No sequence wildcard → fixed-length AC matching
	if #pChildren ~= #nChildren then return nil end
	return Rewrite._matchMultiset(pChildren, nChildren, bindings)
end

-- Match function arguments
function Rewrite._matchArgs(pArgs, nArgs, bindings)
	local i, j = 1, 1

	while i <= #pArgs do
		local p = pArgs[i]

		if isSeqWildcard(p) then
			local key = p.name
			local kind = classifySeqWildcard(key)

			-- bind remaining args as a list
			local slice = {}
			for k = j, #nArgs do
				local arg = nArgs[k]

				if kind == "num" and arg.kind ~= "num" then
					return nil
				elseif kind == "var" and arg.kind ~= "var" then
					return nil
				end

				table_insert(slice, arg)
			end

			if bindings[key] then
				-- require same list
				if not Util.nodeListEquals(bindings[key], slice) then
					return nil
				end
			else
				bindings[key] = slice
			end

			return bindings
		else
			if j > #nArgs then return nil end
			bindings = Rewrite._match(p, nArgs[j], bindings)
			if not bindings then return nil end
			i += 1
			j += 1
		end
	end

	if j <= #nArgs then
		-- extra args not matched
		return nil
	end

	return bindings
end

-- Matching function
-- Handles wildcards as well.
function Rewrite._match(pattern, node, bindings)
	bindings = bindings or {}

	-- Pattern variable wildcard (e.g., Node.Var("_x"), Node.Var("_n"), Node.Var("_v"))
	if pattern.kind == "var" and isWildcardName(pattern.name) then
		local key = pattern.name

		-- Enforce type constraints based on wildcard kind
		local kind = classifySingleWildcard(key)
		if kind == "num" and not (node.kind == "num" or node.kind == "rat") then
			return nil
		elseif kind == "var" and node.kind ~= "var" then
			return nil
		end

		if bindings[key] then
			if Util.nodeEquals(bindings[key], node) then
				return bindings
			else
				return nil
			end
		else
			bindings[key] = node
			return bindings
		end
	end

	-- Exact match
	if pattern.kind ~= node.kind then return nil end

	if pattern.kind == "num" then
		if node.kind == "num" then
			return (pattern.value == node.value) and bindings or nil
		elseif node.kind == "rat" then
			return (node.num == tonumber(pattern.value) and node.den == 1) and bindings or nil
		else
			return nil
		end
	end

	if pattern.kind == "var" then
		return (pattern.name == node.name) and bindings or nil
	end

	if pattern.kind == "func" then
		if pattern.name ~= node.name then return nil end

		return Rewrite._matchArgs(pattern.args, node.args, bindings)
	end

	if pattern.kind == "op" then
		if pattern.op ~= node.op then return nil end

		local info = OpInfo[pattern.op]

		if info and info.assoc and info.comm then
			return Rewrite._matchAC(pattern, node, bindings)
		end

		-- Non-commutative: normal matching
		bindings = Rewrite._match(pattern.left, node.left, bindings)
		if not bindings then return nil end
		return Rewrite._match(pattern.right, node.right, bindings)
	end
end

-------------------------------------------------------
-- Substitute Pattern
-------------------------------------------------------

-- Substitute patterns.
function Rewrite.substitutePattern(node, bindings)
	local kind = node.kind

	-- Single-node wildcard
	if kind == "var" and node.name:match("^_") and not node.name:match("s$") then
		return bindings[node.name] or node
	end

	-- Sequence wildcard inside function args
	if kind == "var" and node.name:match("^_") and node.name:match("s$") then
		-- Should only appear inside function args
		return bindings[node.name] or {}
	end

	-- Numbers unchanged
	if kind == "num" then
		return node
	end
	
	-- Rationals unchanged
	if kind == "rat" then 
		return node 
	end

	-- Function: substitute args
	if kind == "func" then
		local newArgs = {}
		for i, arg in ipairs(node.args) do
			local sub = Rewrite.substitutePattern(arg, bindings)

			-- If sub is a list (sequence wildcard), splice it
			if type(sub) == "table" and sub[1] and sub[1].kind then
				for _, v in ipairs(sub) do
					table_insert(newArgs, v)
				end
			else
				table_insert(newArgs, sub)
			end
		end
		return Node.Func(node.name, newArgs)
	end

	-- Operator: handle AC expansion
	if kind == "op" then
		local left = Rewrite.substitutePattern(node.left, bindings)
		local right = Rewrite.substitutePattern(node.right, bindings)

		-- If left is a sequence wildcard expansion
		if type(left) == "table" and left[1] and left[1].kind then
			local acc = left[1]
			for i = 2, #left do
				acc = Node.Op(node.op, acc, left[i])
			end
			return Node.Op(node.op, acc, right)
		end

		-- If right is a sequence wildcard expansion
		if type(right) == "table" and right[1] and right[1].kind then
			local acc = left
			for i = 1, #right do
				acc = Node.Op(node.op, acc, right[i])
			end
			return acc
		end

		return Node.Op(node.op, left, right)
	end

	return node
end

-------------------------------------------------------
-- Rule Constructors
-------------------------------------------------------

-- Constructs a rule.
-- patternStr: the pattern to be replaced
-- replaceStr: the string to replace the pattern
function Rewrite.Rule(patternStr, replaceStr)
	local pattern = DSL.parse(patternStr)
	local replaceNode = DSL.parse(replaceStr)

	return {
		pattern = pattern,
		replace = function(_, bindings)
			return Rewrite.substitutePattern(replaceNode, bindings)
		end
	}
end

-- Constructs a functional replacement rule.
-- patternStr: the pattern to be replaced
-- fn: the function to be fired with the pattern string.
function Rewrite.RuleFn(patternStr, fn)
	return {
		pattern = DSL.parse(patternStr),
		replace = fn
	}
end

-- Convenience rules

Rewrite.R = Rewrite.Rule
Rewrite.RF = Rewrite.RuleFn

-- The Rewrite sub-library
return Rewrite