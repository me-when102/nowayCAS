local nowayCAS = require(game.ReplicatedStorage.nowayCAS.nowayCAS)

local exprs = {
	"3(x + 1)^2 - 3x^2 - 6x",
	"(a + b)(c + d) - (a + b)",
	"-(x + y + z) + 4x - 2y",
	"2(x + 3)^2 - 4(x^2 + 6x + 9) + 18"
}

for _, s in ipairs(exprs) do
	local e1 = nowayCAS.new(s):expand()
	local e2 = e1:expand()
	print("s: ", s)
	print("e1: ", e1)
	print("e2: ", e2)
end