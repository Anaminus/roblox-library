-- FIFO Implements an expandable circular buffer.
--
-- https://blog.labix.org/2010/12/23/efficient-algorithm-for-expanding-circular-buffers
local FIFO = {__index={}}

-- Push puts a value into the queue.
function FIFO.__index:Push(value)
	local expandbuf, expandring
	if self.ringcap ~= self.bufcap then
		expandbuf = self.pushidx == 0
	elseif self.ringcap == self.ringlen then
		expandbuf = true
		expandring = self.pushidx == 0
	end
	if expandbuf then
		self.pushidx = self.bufcap
		self.bufcap = self.bufcap + 1
		if expandring then
			self.ringcap = self.bufcap
		end
	end

	self.buffer[self.pushidx+1] = value
	self.buflen = self.buflen + 1
	if self.pushidx < self.ringcap then
		self.ringlen = self.ringlen + 1
	end
	self.pushidx = (self.pushidx + 1) % self.bufcap
end

-- Pop takes a value out of the queue. Returns nil if there are no values in the
-- queue.
function FIFO.__index:Pop()
	if self.buflen == 0 then
		return nil
	end
	local value = self.buffer[self.popidx+1]
	self.buffer[self.popidx+1] = nil
	self.buflen = self.buflen - 1
	self.ringlen = self.ringlen - 1
	if self.ringlen == 0 and self.buflen ~= 0 then
		self.popidx = self.ringcap
		self.ringlen = self.buflen
		self.ringcap = self.bufcap
	else
		self.popidx = (self.popidx + 1) % self.ringcap
	end
	return value
end

-- Len returns the number of items in the queue.
function FIFO.__index:Len()
	return self.buflen
end

-- NewFIFO returns a queue suitable for first-in, first-out operations.
local function NewFIFO()
	return setmetatable({
		buffer = {},
		buflen = 0,
		ringlen = 0,
		pushidx = 0,
		popidx = 0,
		bufcap = 0,
		ringcap = 0,
	}, FIFO)
end
