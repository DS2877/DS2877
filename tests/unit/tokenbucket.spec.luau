--!strict
local h = require("./helpers")
local TokenBucket = require("../../src/shared/Logic/TokenBucket")

h.suite("TokenBucket")

h.test("allows a burst up to capacity then refuses", function()
	local bucket = TokenBucket.new(3, 1, 0)
	h.expectTrue(TokenBucket.consume(bucket, 0), "first")
	h.expectTrue(TokenBucket.consume(bucket, 0), "second")
	h.expectTrue(TokenBucket.consume(bucket, 0), "third")
	h.expectEqual(TokenBucket.consume(bucket, 0), false, "fourth should be refused")
end)

h.test("refills over time", function()
	local bucket = TokenBucket.new(3, 1, 0)
	for _ = 1, 3 do
		TokenBucket.consume(bucket, 0)
	end
	h.expectEqual(TokenBucket.consume(bucket, 0.5), false, "half a token is not enough")
	h.expectTrue(TokenBucket.consume(bucket, 1), "one second restores one token")
end)

h.test("never refills past capacity", function()
	local bucket = TokenBucket.new(2, 1, 0)
	TokenBucket.consume(bucket, 1000)
	h.expectTrue(TokenBucket.consume(bucket, 1000), "second token still available")
	h.expectEqual(TokenBucket.consume(bucket, 1000), false, "but not a third")
end)

h.test("tolerates clock going backwards", function()
	-- os.clock() should be monotonic, but a negative elapsed must never mint tokens.
	local bucket = TokenBucket.new(1, 1, 100)
	TokenBucket.consume(bucket, 100)
	h.expectEqual(TokenBucket.consume(bucket, 50), false, "backwards time must not refill")
end)

return true
