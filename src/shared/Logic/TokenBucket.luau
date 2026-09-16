--!strict
--[[
	Per-player rate limiting for remotes.

	DEPENDENCY-FREE so tests/unit can exercise it under Lune. Time is passed in
	rather than read from `os.clock()`, which is what makes it testable at all.

	Every remote declared in shared/Net carries a bucket. The server rejects
	anything over budget rather than trusting the client to behave
	(docs/COMPLIANCE.md section 8).
]]

local TokenBucket = {}
TokenBucket.__index = TokenBucket

export type Bucket = {
	capacity: number,
	refillPerSecond: number,
	tokens: number,
	lastRefill: number,
}

--- `capacity` is the burst allowance; `refillPerSecond` the sustained rate.
function TokenBucket.new(capacity: number, refillPerSecond: number, now: number): Bucket
	assert(capacity > 0, "capacity must be positive")
	assert(refillPerSecond > 0, "refillPerSecond must be positive")
	return {
		capacity = capacity,
		refillPerSecond = refillPerSecond,
		tokens = capacity,
		lastRefill = now,
	}
end

--- Tries to spend one token. Returns true if the call is allowed.
function TokenBucket.consume(bucket: Bucket, now: number, cost: number?): boolean
	local spend = cost or 1
	local elapsed = math.max(0, now - bucket.lastRefill)
	bucket.tokens = math.min(bucket.capacity, bucket.tokens + elapsed * bucket.refillPerSecond)
	bucket.lastRefill = now

	if bucket.tokens >= spend then
		bucket.tokens -= spend
		return true
	end
	return false
end

return TokenBucket
