local PrintHelpers = {}

local Util = require(script.Parent.Parent.Util)

PrintHelpers.PRECEDENCE = {
	-- Boolean logic
	["or"]  = 1,
	["and"] = 2,
	["not"] = 3,   -- unary, but treat as high-precedence prefix

	-- Comparisons
	[">"]  = 4,
	["<"]  = 4,
	[">="] = 4,
	["<="] = 4,
	["=="] = 4,
	["!="] = 4,

	-- Arithmetic
	["+"] = 5,
	["-"] = 5,
	["*"] = 6,
	["/"] = 6,

	-- Unary minus
	["u-"] = 7,

	-- Exponentiation
	["^"] = 8,
}

PrintHelpers.unicodeConstants = {
	pi  = "π",
	phi = "φ",
	tau = "τ",
}

-- Checks if the node is a variable
function PrintHelpers.isBareVar(n)
	return Util.isVar(n) or Util.isConst(n)
end

-- Checks if the node is just var^number.
function PrintHelpers.isSimplePower(n)
	return Util.isOp(n)
		and n.op == "^"
		and Util.isVar(n.left)
		and Util.isNum(n.right)
end

-- Checks if the node is a simple variable.
function PrintHelpers.isSimple(n)
	return Util.isNum(n)
		or Util.isRat(n)
		or Util.isVar(n)
		or Util.isFunc(n)
		or Util.isConst(n)
		or PrintHelpers.isSimplePower(n)
end

-- Checks if n is just one letter.
function PrintHelpers.isSingleVarName(n)
	return Util.isVar(n) and #n.name > 1
end

-- Checks if the node is a unary minus.
function PrintHelpers.isUnaryMinus(node)
	return Util.isOp(node)
		and node.op == "*"
		and Util.isNum(node.left)
		and node.left.value == "-1"
end

return PrintHelpers