local nowayCAS = require(game.ReplicatedStorage.nowayCAS.nowayCAS)

local function roundtrip(expr)
	local token = nowayCAS.Token._tokenize(expr)
	local ast = nowayCAS.Parser.parse(token)
	local canon = nowayCAS.Canon.canonical(ast)
	return canon
end

local function assert_equal_ast(a, b, msg)
	if not nowayCAS.Util.nodeEquals(a, b) then
		error(("AST mismatch: %s\nA = %s\nB = %s")
			:format(msg or "",
				nowayCAS.Print._toString(a),
				nowayCAS.Print._toString(b)))
	end
end

-- Runs a single canonicalization test.
function test(expr, expected)
	local canon = roundtrip(expr)
	local expected_token = nowayCAS.Token._tokenize(expected)
	local expected_ast = nowayCAS.Parser.parse(expected_token)
	assert_equal_ast(canon, expected_ast,
		("canonicalization of %q should be %q"):format(expr, expected))
end

-- Ensures canonicalization is idempotent.
function idempotent(expr)
	local ast1 = roundtrip(expr)
	local ast2 = nowayCAS.Canon.canonical(ast1)
	assert_equal_ast(ast1, ast2,
		("canonicalization should be idempotent for %q"):format(expr))
end

-- Ensures pretty-print roundtrip is stable.
function pretty_roundtrip(expr)
	local canon = roundtrip(expr)
	local printed = nowayCAS.Print._toString(canon)
	local reparsed_token = nowayCAS.Token._tokenize(printed)
	local reparsed = nowayCAS.Parser.parse(reparsed_token)
	local recanon = nowayCAS.Canon.canonical(reparsed)
	assert_equal_ast(canon, recanon,
		("pretty roundtrip should preserve canonical form for %q"):format(expr))
end

-- Associative flattening
test("a + (b + c)", "a + b + c")
test("(a + b) + (c + d)", "a + b + c + d")

-- Commutative sorting
test("b + a", "a + b")
test("x * z * y", "x * y * z")

-- Neutral elements
test("a + 0", "a")
test("0 + a", "a")
test("a * 1", "a")
test("1 * a", "a")
test("a * 0", "0")

-- Unary cleanup
test("+(+a)", "a")
test("--a", "a")

-- Idempotence
idempotent("a + (b + c)")
idempotent("x * (y * z)")

-- Pretty roundtrip (optional)
pretty_roundtrip("a + b + c")
pretty_roundtrip("x * (y + z)")

print("done")