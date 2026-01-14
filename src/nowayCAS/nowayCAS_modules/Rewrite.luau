local Rewrite = {}

local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)
local RewriteDSL = require(script.RewriteDSL)
local RewriteRuleHelpers = require(script.RewriteRuleHelpers)

local table_remove = table.remove
local table_insert = table.insert

local ipairs = ipairs

-------------------------------------------------------
-- Rewrite
-------------------------------------------------------

local OpInfo = {
	["+"]  = { assoc = true,  comm = true  },
	["*"]  = { assoc = true,  comm = true  },

	["-"]  = { assoc = false, comm = false },
	["/"]  = { assoc = false, comm = false },

	-- Logical operators
	["and"] = { assoc = false, comm = false },
	["or"]  = { assoc = false, comm = false },

	-- Comparison operators
	[">"]  = { assoc = false, comm = false },
	["<"]  = { assoc = false, comm = false },
	[">="] = { assoc = false, comm = false },
	["<="] = { assoc = false, comm = false },
	["=="] = { assoc = false, comm = false },
	["!="] = { assoc = false, comm = false },
}

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
	if Util.isOp(node) then
		local left, changedL = Rewrite._rewrite(node.left, rules)
		local right, changedR = Rewrite._rewrite(node.right, rules)

		if changedL or changedR then
			node = Node.Op(node.op, left, right)
		end

	elseif Util.isFunc(node) then
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

	elseif Util.isPiecewise(node) then
		local changed = false
		local newBranches = {}

		for i, pair in ipairs(node.branches) do
			local cond, cChanged = Rewrite._rewrite(pair[1], rules)
			local expr, eChanged = Rewrite._rewrite(pair[2], rules)

			changed = changed or cChanged or eChanged
			newBranches[i] = { cond, expr }
		end

		if changed then
			node = Node.Piecewise(newBranches)
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
	local maxSteps = 50
	local steps = 0

	while steps < maxSteps do
		local next, changed = Rewrite._rewrite(node, rules)
		if not changed then
			return node
		end
		node = next
		steps += 1
	end
	if steps >= maxSteps then
		warn("Rewrite.apply: maxSteps reached, exhausted rewriting execution.")
	end
	return node
end

-------------------------------------------------------
-- Pattern-matching system
--
-- This is going to be documented.
--
-- Single-node wildcards:
--
--		_x -> matches any node
--		_n -> matches numeric nodes (num or rat)
--		_v -> matches variable nodes
--
--		These binds a single node. If the same wildcard
--		appears multiple times, all occurrences must
--		match the same node (structural equality).
--
-- Sequence wildcards:
--
--		_xs -> matches a sequence of any nodes
--		_ns -> matches a sequence of numeric nodes
--		_vs -> matches a sequence of variable nodes
--
--		These only appear inside:
--			- function argument lists
--			- AC operator children (eg: +, *)
--		They bind a list of nodes. When substituted,
--		the list is spliced into the surrounding structure.
--
-- Associative-Commutative (AC) matching:
--
--		Operators + and * are treated as AC:
--			- children are flattened (a+(b+c) -> {a,b,c})
--			- order does not matter
--			- sequence wildcards may absorb multiple children
--
--		Example:
--			Pattern: 	_x + ys
--			Node: 		a + b + c
--			Bindings: 	_x = a
--					  	_ys = {b, c}
--
-- Non-AC operators:
--		-, /, and all function calls match structurally:
--			- left/right must match exactly
--			- no reordering or flattening
--
-- Replacement:
--    	Rewrite.substitutePattern() replaces wildcards
--    	using the bindings produced by _match().
--    	Sequence wildcards splice their lists into:
--      	- function argument lists
--      	- AC operator chains
--
-- Rule constructors:
--      Rewrite.Rule(patternStr, replaceStr)
--        -> both parsed by RewriteDSL.parse()
--
--      Rewrite.RuleFn(patternStr, fn)
--        -> fn receives (node, bindings)
--
--    	Example:
--      	Rewrite.R("_x + 0", "_x")
--      	Rewrite.RF("_n * _x", function(node, b)
--          	return Node.Op("*", b["_n"], b["_x"])
--      	end)
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
	return Util.isVar(pattern)
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
		if Util.isVar(p) and isSeqWildcard(p) then
			return i, p
		end
	end
	return nil
end

-- Matches Associative-Commutative operators in a sequence
function Rewrite._matchACSeq(pattern, node, bindings)
	local pChildren = RewriteRuleHelpers.childrenOf(pattern, pattern.op)
	local nChildren = RewriteRuleHelpers.childrenOf(node, node.op)

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
				if seqKind == "num" then
					-- numeric sequence: allow num or rat
					if not Util.isNum(n) then
						return nil
					end

				elseif seqKind == "var" then
					-- variable sequence: must be a var
					if not Util.isVar(n) then
						return nil
					end
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
	local pChildren = RewriteRuleHelpers.childrenOf(pattern, pattern.op)
	local nChildren = RewriteRuleHelpers.childrenOf(node, node.op)

	-- Check for sequence wildcard
	local seqIndex = findSeqWildcard(pChildren)
	if seqIndex then
		return Rewrite._matchACSeq(pattern, node, bindings)
	end

	-- No sequence wildcard -> fixed-length AC matching
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

				-- numeric sequence: allow num or rat
				if kind == "num" and not Util.isNumeric(arg) then
					return nil
				end

				-- variable sequence: must be a var
				if kind == "var" and not Util.isVar(arg) then
					return nil
				end

				table_insert(slice, arg)
			end

			-- enforce consistency if already bound
			if bindings[key] then
				if not Util.nodeListEquals(bindings[key], slice) then
					return nil
				end
			else
				bindings[key] = slice
			end

			return bindings
		else
			-- no more args to match
			if j > #nArgs then
				return nil
			end

			bindings = Rewrite._match(p, nArgs[j], bindings)
			if not bindings then
				return nil
			end

			i += 1
			j += 1
		end
	end

	-- extra unmatched args
	if j <= #nArgs then
		return nil
	end

	return bindings
end

-- Matching function
-- Handles wildcards as well.
function Rewrite._match(pattern, node, bindings)
	bindings = bindings or {}

	-- Wildcard variable (e.g. _x, _n, _v)
	if Util.isVar(pattern) and isWildcardName(pattern.name) then
		local key = pattern.name
		local kind = classifySingleWildcard(key)

		-- numeric wildcard: allow num or rat
		if kind == "num" and not Util.isNumeric(node) then
			return nil
		end

		-- variable wildcard: must be a var
		if kind == "var" and not Util.isVar(node) then
			return nil
		end

		-- enforce consistent binding
		if bindings[key] then
			return Util.nodeEquals(bindings[key], node) and bindings or nil
		else
			bindings[key] = node
			return bindings
		end
	end

	-- Exact kind match required
	if pattern.kind ~= node.kind then
		return nil
	end

	-- Numeric literal
	if Util.isNumeric(pattern) then
		if Util.isNum(node) then
			return (pattern.value == node.value) and bindings or nil
		end

		if Util.isRat(node) then
			return (node.num == tonumber(pattern.value) and node.den == 1)
				and bindings
				or nil
		end

		return nil
	end

	-- Variable literal
	if Util.isVar(pattern) then
		return (pattern.name == node.name) and bindings or nil
	end

	-- Function
	if Util.isFunc(pattern) then
		if pattern.name ~= node.name then
			return nil
		end

		return Rewrite._matchArgs(pattern.args, node.args, bindings)
	end

	-- Operator
	if Util.isOp(pattern) then
		if pattern.op ~= node.op then
			return nil
		end

		local info = OpInfo[pattern.op]

		-- AC operator (associative + commutative)
		if info and info.assoc and info.comm then
			return Rewrite._matchAC(pattern, node, bindings)
		end

		-- Non‑commutative: match left then right
		bindings = Rewrite._match(pattern.left, node.left, bindings)
		if not bindings then
			return nil
		end

		return Rewrite._match(pattern.right, node.right, bindings)
	end

	-- Unknown node kind (should never happen)
	return nil
end

-------------------------------------------------------
-- Substitute Pattern
-------------------------------------------------------

-- Substitute patterns.
function Rewrite.substitutePattern(node, bindings)
	-- Single-node wildcard
	if Util.isVar(node)
		and node.name:match("^_")
		and not node.name:match("s$") then
		return bindings[node.name] or node
	end

	-- Sequence wildcard inside function args
	if Util.isVar(node)
		and node.name:match("^_")
		and node.name:match("s$") then
		-- Should only appear inside function args
		return bindings[node.name] or {}
	end

	-- Numeric nodes unchanged
	if Util.isNumeric(node) then
		return node
	end

	-- Function: substitute args
	if Util.isFunc(node) then
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
	if Util.isOp(node) then
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

	-- Piecewise: substitute inside branches
	if Util.isPiecewise(node) then
		local newBranches = {}
		for i, pair in ipairs(node.branches) do
			local cond = Rewrite.substitutePattern(pair[1], bindings)
			local expr = Rewrite.substitutePattern(pair[2], bindings)
			newBranches[i] = { cond, expr }
		end
		return Node.Piecewise(newBranches)
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
	local pattern = RewriteDSL.parse(patternStr)
	local replaceNode = RewriteDSL.parse(replaceStr)

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
		pattern = RewriteDSL.parse(patternStr),
		replace = fn
	}
end

-- Convenience rules

Rewrite.R = Rewrite.Rule
Rewrite.RF = Rewrite.RuleFn

-- The Rewrite sub-library.
return Rewrite