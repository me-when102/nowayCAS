local nowayCAS = require(game.ReplicatedStorage.nowayCAS.nowayCAS)

local tests = {
	-- Common factor
	{ "4x*f*a^2 + 4y*f*a^2 + 8z*f*a^2", "4a^2f(x + y + 2z)" },

	-- Bilinear grouping
	{ "x*y*t + x*z*t + w*y*d + w*z*d", "(x + w)(y + z)" },
	{ "a*b + a*c + d*b + d*c", "(a + d)(b + c)" },

	-- Binomial
	{ "x^2 - 9", "(x - 3)(x + 3)" },

	-- Perfect squares
	{ "x^2 + 2*x*y + y^2", "(x + y)^2" },
	{ "x^2 - 2*x*y + y^2", "(x - y)^2" },

	-- More cases you’ll want soon:
	{ "9x^2 - 25y^2", "(3x - 5y)(3x + 5y)" },
	{ "4x^2 + 12x + 9", "(2x + 3)^2" },
	{ "49a^2 - 14ab + b^2", "(7a - b)^2" },
	{ "m^2 + 5mn + 6n^2", "(m + 2n)(m + 3n)" },
	{ "2x^2 + 8x", "2x(x + 4)" },
	{ "6a^2b + 9ab^2", "3ab(2a + 3b)" },
}

local function runTests()
	print("=== FACTORIZATION TESTS ===")

	for i, case in ipairs(tests) do
		local input = case[1]
		local expected = case[2]

		local result = nowayCAS.new(input):factor():toString()

		-- Canonicalize expected so ordering differences don’t cause false failures
		local expectedCanon = nowayCAS.new(expected):simplify():toString()
		local resultCanon = nowayCAS.new(result):simplify():toString()

		local ok = nowayCAS.Util.nodeEquals(expectedCanon, resultCanon)

		if ok then
			print(("PASS %02d: %s → %s"):format(i, input, result))
		else
			print(("FAIL %02d: %s"):format(i, input))
			print("  got:     ", result)
			print("  expect:  ", expected)
			print("  got(c):  ", resultCanon)
			print("  exp(c):  ", expectedCanon)
		end
	end
end

runTests()