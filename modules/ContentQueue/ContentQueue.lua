--@sec: ContentQueue
--@ord: -1
--@doc: The **ContentQueue** module provides ordered content preloading.
local export = {}

local ContentProvider = game:GetService("ContentProvider")

--@sec: ContentQueue.new
--@def: function ContentQueue.new(callback: Callback?): Queue
--@doc: The **new** constructor returns a new queue with an optional callback.
function export.new(callback: Callback?): Queue
	local active: boolean = false -- Whether a group is preloading.
	local queue: {thread} = {} -- List of
	local threads: {[any]: {[number]: thread, appends: number}} = {}
	local self = {}
	--@sec: Queue.Add
	--@def: function Queue:Add(id: any, content: {Instance|string})
	--@doc: The **Add** method queues *content* to be preloaded under the group
	-- identified by *id*, then returns immediately. After the content has
	-- finished loading, the group is removed from the queue. Multiple groups
	-- with the same identifier may be queued at once, and are added to the end
	-- of the queue as usual.
	--
	-- *content* is passed directly to [ContentProvider.PreloadAsync][pa].
	--
	-- [pa]: https://developer.roblox.com/en-us/api-reference/function/ContentProvider/PreloadAsync
	function self:Add(id: any, content: {Instance|string})
		assert(id ~= nil, "id must be non-nil")
		if not threads[id] then
			threads[id] = {appends=0}
		end
		threads[id].appends += 1
		task.spawn(function(threads, id, content, callback)
			if active then
				table.insert(queue, coroutine.running())
				coroutine.yield()
			end
			active = true
			if callback then
				ContentProvider:PreloadAsync(content, function(asset, status)
					callback(id, asset, status)
				end)
			else
				ContentProvider:PreloadAsync(content)
			end
			local list = threads[id]
			list.appends -= 1
			if list.appends > 0 then
				return
			end
			threads[id] = nil
			for _, thread in ipairs(list) do
				task.spawn(thread)
			end
			if #queue > 0 then
				task.spawn(table.remove(queue, 1)::thread)
			else
				active = false
			end
		end, threads, id, content, callback)
	end
	--@sec: Queue.Has
	--@def: function Queue:Has(id: any): boolean
	--@doc: The **Has** method returns whether the queue contains at least one
	-- group identified by *id*.
	function self:Has(id: string)
		return not not threads[id]
	end
	--@sec: Queue.WaitFor
	--@def: function Queue:WaitFor(id: any)
	--@doc: The **WaitFor** method waits until no groups identified by *id* are
	-- in the queue. If no groups of *id* are in the queue, then WaitFor returns
	-- immediately.
	function self:WaitFor(id: string)
		if threads[id] then
			table.insert(threads[id], coroutine.running())
			coroutine.yield()
		end
	end
	return self
end

--@sec: Callback
--@def: type Callback = (id: any, asset: string, status: Enum.AssetFetchStatus) -> ()
--@doc: Callback is called when an asset has finished loading. *id* is the
-- identifier of the group from which the asset was loaded. *asset* is a Content
-- string. *status* indicates whether *asset* was successfully fetched.
export type Callback = (id: any, asset: string, status: Enum.AssetFetchStatus) -> ()

--@sec: Queue
--@def: type Queue
--@doc: Queue is an object that preloads content in a ordered manner. Isolated
-- **groups** of content can be added to the queue, which are processed
-- first-in-first-out. A group will only start preloading its content once it is
-- first in the queue.
export type Queue = {
	Add: (self: Queue, id: any, content: {Instance|string}) -> (),
	Has: (self: Queue, id: any) -> (),
	WaitFor: (self: Queue, id: any) -> (),
}

return table.freeze(export)
