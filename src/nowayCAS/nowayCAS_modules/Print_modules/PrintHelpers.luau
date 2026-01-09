local PrintHelpers = {}

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
	return (n.kind == "var" or n.kind == "const")
end

-- Checks if the node is just var^number.
function PrintHelpers.isSimplePower(n)
	return n.kind == "op"
		and n.op == "^"
		and n.left.kind == "var"
		and n.right.kind == "num"
end

-- Checks if the node is a simple variable.
function PrintHelpers.isSimple(n)
	return n.kind == "num"
		or n.kind == "rat"
		or n.kind == "var"
		or n.kind == "func"
		or n.kind == "const"
		or PrintHelpers.isSimplePower(n)
end

-- Checks if n is just one letter.
function PrintHelpers.isSingleVarName(n)
	return n.kind == "var" and #n.name > 1
end

-- Checks if the node is a unary minus.
function PrintHelpers.isUnaryMinus(node)
	return node.kind == "op"
		and node.op == "*"
		and node.left.kind == "num"
		and node.left.value == "-1"
end

return PrintHelpers