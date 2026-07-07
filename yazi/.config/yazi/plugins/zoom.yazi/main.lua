--- @since 26.1.22

local get = ya.sync(function(st, url) return st.last == url and st.level end)
local latest = ya.sync(function(st, url, level) return st.last == url and st.level == level end)

local MIN_LEVEL, MAX_LEVEL, STEP = 0, 10, 0.15
local BASE_FIT = 0.66
local WIDE_BASE_FIT = 0.86
local FALLBACK_CELL_W, FALLBACK_CELL_H = 10, 20

local save = ya.sync(function(st, url, new)
	local h = cx.active.current.hovered
	if h and h.url == url then
		st.last, st.level = url, new
		return true
	end
end)

local move = ya.sync(function(st, motion, reset)
	local h = cx.active.current.hovered
	if not h then
		return
	end

	if st.last ~= h.url then
		st.last, st.level = Url(h.url), 0
	end

	local old = st.level
	local new = reset and 0 or ya.clamp(MIN_LEVEL, old + motion, MAX_LEVEL)
	local changed = reset or new ~= old
	if changed then
		st.level = new
	end

	return { url = h.url, old = old, level = st.level, changed = changed }
end)

local function end_(job, err)
	if not job.old_level then
		ya.preview_widget(job, err and ui.Text(err):area(job.area):wrap(ui.Wrap.YES))
	elseif err then
		ya.notify { title = "Zoom", content = tostring(err), timeout = 5, level = "error" }
	end
end

local function canvas(area)
	local cw, ch = rt.term.cell_size()
	if not cw or cw <= 0 or not ch or ch <= 0 then
		cw, ch = FALLBACK_CELL_W, FALLBACK_CELL_H
	end

	return math.min(rt.preview.max_width, math.floor(area.w * cw)),
		math.min(rt.preview.max_height, math.floor(area.h * ch))
end

local function fit(info, max_w, max_h, ratio)
	local limit_w = math.max(1, math.floor(max_w * ratio))
	local limit_h = math.max(1, math.floor(max_h * ratio))
	local scale = math.min(limit_w / info.w, limit_h / info.h, 1)

	return math.max(1, math.floor(info.w * scale)),
		math.max(1, math.floor(info.h * scale))
end

local function base_fit(area)
	return area.w >= 70 and WIDE_BASE_FIT or BASE_FIT
end

local function peek(_, job)
	local url = job.file.url
	local info, err = ya.image_info(url)
	if not info then
		return end_(job, Err("Failed to get image info: %s", err))
	end

	local requested = job.new_level
	if requested == nil then
		requested = get(Url(url)) or tonumber(job.args[1]) or 0
		save(url, requested)
	end

	if job.area.w <= 0 or job.area.h <= 0 then
		return end_(job, "Preview pane is hidden; press z p or z r to show it.")
	end

	local max_w, max_h = canvas(job.area)
	if max_w <= 0 or max_h <= 0 then
		return end_(job, "Preview pane is hidden; press z p or z r to show it.")
	end

	local base_w, base_h = fit(info, max_w, max_h, base_fit(job.area))
	local max_level = math.max(0, math.min(
		MAX_LEVEL,
		math.floor((max_w / base_w - 1) / STEP),
		math.floor((max_h / base_h - 1) / STEP)
	))
	if job.old_level and job.old_level > max_level and (job.motion or 0) < 0 then
		requested = max_level + job.motion
	end

	local before_clamp = requested
	local level = ya.clamp(MIN_LEVEL, requested, max_level)
	requested = level
	if job.old_level and level ~= before_clamp then
		save(url, level)
	end

	if job.old_level and level == job.old_level and (job.motion or 0) > 0 then
		ya.notify { title = "Zoom", content = "Already at maximum preview size", timeout = 2, level = "warn" }
		return
	elseif job.old_level and level == job.old_level and (job.motion or 0) < 0 then
		ya.notify { title = "Zoom", content = "Already at minimum preview size", timeout = 2, level = "warn" }
		return
	end

	local scale = math.max(0.1, 1 + level * STEP)
	local new_w = math.min(max_w, math.max(1, math.floor(base_w * scale)))
	local new_h = math.min(max_h, math.max(1, math.floor(base_h * scale)))

	local tmp = os.tmpname()
	-- stylua: ignore
	local output, err = Command("magick"):arg {
		tostring(job.file.path),
		"-auto-orient", "-strip",
		"-sample", string.format("%dx%d", new_w, new_h),
		"-quality", rt.preview.image_quality,
		string.format("WEBP:%s", tmp),
	}:output()

	if not output then
		end_(job, Err("Failed to start `magick`, error: %s", err))
	elseif not output.status.success then
		end_(job, Err("`magick` exited with error code %s: %s", output.status.code, output.stderr))
	elseif not job.old_level or latest(url, requested) then
		ya.image_show(Url(tmp), job.area)
	end
	end_(job)
end

local function entry(self, job)
	local arg = job.args[1]
	local reset = arg == "reset"
	local motion = reset and 0 or tonumber(arg) or 0
	local st = move(motion, reset)
	if not st then
		return
	end

	if st.changed then
		peek(self, {
			area = ui.area("preview"),
			args = {},
			file = File { url = st.url, cha = Cha { mode = tonumber("100644", 8) } },
			skip = 0,
			new_level = st.level,
			old_level = st.old,
			motion = motion,
		})
	elseif motion > 0 then
		ya.notify { title = "Zoom", content = "Already at maximum preview size", timeout = 2, level = "warn" }
	elseif motion < 0 then
		ya.notify { title = "Zoom", content = "Already at minimum preview size", timeout = 2, level = "warn" }
	end
end

return { peek = peek, entry = entry }
