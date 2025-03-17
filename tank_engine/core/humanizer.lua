-- Tank Engine Humanizer
-- Controls execution timing to prevent detection

TE.humanizer = {
    next_run = 0,
}

---Applies jitter to a delay value
---@param delay number The base delay value
---@param latency number The current latency value
---@return number The delay with jitter applied
local function apply_jitter(delay, latency)
    if not TE.settings.jitter.is_enabled() then
        return delay
    end

    local latency_factor = math.min(latency / 200, 1) -- Normalize latency impact

    -- Calculate jitter percentage based on base jitter and latency
    local jitter_percent = TE.settings.jitter.base_jitter() +
        (TE.settings.jitter.latency_jitter() * latency_factor)

    -- Clamp total jitter to max_jitter
    jitter_percent = math.min(jitter_percent, TE.settings.jitter.max_jitter())

    -- Calculate jitter range
    local jitter_range = delay * jitter_percent

    -- Apply random jitter within range
    return delay + (math.random() * 2 - 1) * jitter_range
end

-- Check if we can run based on timing
function TE.humanizer.can_run()
    return core.game_time() >= TE.humanizer.next_run
end

-- Update the next run time
function TE.humanizer.update()
    local latency = core.get_ping() * 1.5
    local min_delay = TE.settings.min_delay() + latency
    local max_delay = TE.settings.max_delay() + latency

    -- Get base delay
    local base_delay = math.random(min_delay, max_delay)

    -- Apply jitter to the delay
    local final_delay = apply_jitter(base_delay, latency)

    TE.humanizer.next_run = final_delay + core.game_time()
end
