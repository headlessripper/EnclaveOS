-- Enclave OS — Hyprland configuration for the Enclave Shell session.
--
-- Hyprland is Enclave's compositor wherever there is a working GPU: every
-- window floats (a desktop, not a tiling WM), with continuous rounded
-- corners, soft shadows, a hairline frame and frosted-glass blur behind the
-- shell. There are no title bars — windows are driven from the bubble.
-- On machines without 3D graphics, enclave-session uses labwc instead.
--
-- Users can override anything in ~/.config/enclave/hyprland.lua (loaded last).

local function getenv(name)
    local ok, value = pcall(function() return os.getenv(name) end)
    return ok and value or nil
end

------------------------------------------------------------------ monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

------------------------------------------------------------------ environment
hl.env("XCURSOR_THEME", "Enclave-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

------------------------------------------------------------------ look
-- Enclave Ember: obsidian shadows, an ember hairline on the window in front.
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 10,
        border_size = 1,
        col = {
            active_border = { colors = { "rgba(ff7a1a99)", "rgba(ffac5566)" }, angle = 45 },
            inactive_border = "rgba(26262e99)",
        },
        resize_on_border = true,
        extend_border_grab_area = 12,
        hover_icon_on_border = true,
        layout = "dwindle",
        snap = { enabled = true, window_gap = 8, monitor_gap = 10 },
    },

    decoration = {
        rounding = 14,
        rounding_power = 2.6,        -- continuous (squircle) corners, like Enclave's icons
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 28,
            render_power = 3,
            offset = "0 8",
            color = "rgba(00000066)",
            color_inactive = "rgba(00000038)",
        },
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            new_optimizations = true,
            noise = 0.012,
            contrast = 0.95,
            brightness = 0.9,
            vibrancy = 0.17,
            popups = true,
        },
    },

    animations = { enabled = true },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = "rgb(101114)",
        focus_on_activate = true,
        animate_manual_resizes = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        middle_click_paste = true,
        new_float_force_onscreen = 1,
    },

    ecosystem = { no_update_news = true, no_donation_nag = true },

    input = {
        kb_layout = getenv("XKB_DEFAULT_LAYOUT") or "us",
        kb_variant = getenv("XKB_DEFAULT_VARIANT") or "",
        follow_mouse = 2,            -- click to focus, like Windows and macOS
        touchpad = { natural_scroll = true, tap_to_click = true, disable_while_typing = true },
    },

    cursor = { no_hardware_cursors = getenv("WLR_NO_HARDWARE_CURSORS") == "1" },
    binds = { allow_workspace_cycles = true },
    dwindle = { preserve_split = true },
})

-- Motion: quick, springy, never showy (Ember motion tokens: 150–250 ms).
hl.curve("ember", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("emberIn", { type = "bezier", points = { { 0.55, 0 }, { 1, 0.45 } } })
hl.curve("soft", { type = "spring", mass = 1, stiffness = 260, damping = 26 })
hl.animation({ leaf = "global", enabled = true, speed = 6, bezier = "ember" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.6, spring = "soft", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, bezier = "emberIn", style = "popin 94%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.8, spring = "soft" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "ember" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "ember" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "ember", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "emberIn", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "ember", style = "slidefade 12%" })

------------------------------------------------------------------ rules
-- A desktop, not a tiling WM: every window floats, centred, at its own size.
hl.window_rule({ name = "enclave-float", match = { class = ".*" }, float = true })
-- Apps may ask to be maximised; that is the user's call (bubble, Super+Up).
hl.window_rule({ name = "enclave-no-auto-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- Frosted glass behind the shell (dock, widgets, Start, Control Center…).
-- ignore_alpha keeps the clear parts of full-screen overlays unblurred.
hl.layer_rule({ name = "enclave-glass", match = { namespace = "^enclave-(taskbar|widgets|search-widget|search|start|control-center|calendar|flyout)$" },
                blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ name = "enclave-wallpaper", match = { namespace = "^enclave-wallpaper$" }, no_anim = true })
hl.layer_rule({ name = "enclave-bubble", match = { namespace = "^enclave-bubble$" }, no_anim = true })
hl.layer_rule({ name = "enclave-notifications", match = { namespace = "^notifications$" }, blur = true, ignore_alpha = 0.35 })

------------------------------------------------------------------ the enclave bridge
-- The shell (bubble, dock) drives windows through these, via
--   hyprctl eval 'enclave.snap("left")'
-- Minimised windows live on the hidden special workspace "minimized".
enclave = {}

local function dispatch(dsp)
    local ok, err = pcall(function() hl.dispatch(dsp) end)
    if not ok then print("enclave: " .. tostring(err)) end
    return ok
end

-- The usable area of the focused monitor (minus the dock's reserved space).
local function workarea()
    local m = hl.get_active_monitor()
    if not m then return nil end
    local scale = (type(m.scale) == "number" and m.scale > 0) and m.scale or 1
    local w, h = m.width / scale, m.height / scale
    local l, t, r, b = 0, 0, 0, 0
    local res = m.reserved
    if type(res) == "table" then
        l = res.left or res[1] or 0
        t = res.top or res[2] or 0
        r = res.right or res[3] or 0
        b = res.bottom or res[4] or 0
    end
    local gap = 10
    return { x = m.x + l + gap, y = m.y + t + gap, w = w - l - r - 2 * gap, h = h - t - b - 2 * gap }
end

function enclave.minimize(window)
    local target = { workspace = "special:minimized", follow = false }
    if window then target.window = window end
    return dispatch(hl.dsp.window.move(target))
end

function enclave.restore(window)
    local ws = hl.get_active_workspace()
    if not ws or ws.special then return false end
    local target = { workspace = ws.id }
    if window then target.window = window end
    dispatch(hl.dsp.window.move(target))
    local m = hl.get_active_monitor()
    if m and m.active_special_workspace then
        dispatch(hl.dsp.workspace.toggle_special("minimized"))
    end
    return true
end

-- Show desktop: minimise everything on this workspace; again brings it back.
function enclave.show_desktop()
    local ws = hl.get_active_workspace()
    local visible = ws and hl.get_workspace_windows(ws.id) or {}
    if #visible > 0 then
        for _, w in ipairs(visible) do enclave.minimize(w) end
    else
        for _, w in ipairs(hl.get_workspace_windows("special:minimized") or {}) do enclave.restore(w) end
    end
end

function enclave.snap(side)
    local a = workarea()
    if not a then return false end
    local half = math.floor(a.w / 2 - 4)
    local x = side == "right" and (a.x + a.w - half) or a.x
    dispatch(hl.dsp.window.move({ x = math.floor(x), y = math.floor(a.y) }))
    return dispatch(hl.dsp.window.resize({ x = half, y = math.floor(a.h) }))
end

function enclave.center()
    return dispatch(hl.dsp.window.center())
end

-- Requests from the dock (wlr foreign-toplevel "minimise"), and windows
-- activated while minimised (clicked in the dock) come back to this desktop.
hl.on("window.minimize", function(window, minimized)
    if minimized == false then enclave.restore(window) else enclave.minimize(window) end
end)
hl.on("window.active", function(window)
    if window and window.workspace and window.workspace.name == "special:minimized" then
        enclave.restore(window)
    end
end)

------------------------------------------------------------------ keys
local shell = "enclave-shell --command "
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("enclave-shell --toggle-start"), { release = true })
hl.bind("SUPER + S", hl.dsp.exec_cmd(shell .. "start-open"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(shell .. "search"))
hl.bind("SUPER + A", hl.dsp.exec_cmd(shell .. "control-center"))
hl.bind("SUPER + I", hl.dsp.exec_cmd("enclave-settings"))
hl.bind("SUPER + C", hl.dsp.exec_cmd(shell .. "calendar"))
hl.bind("SUPER + W", hl.dsp.exec_cmd(shell .. "widgets"))
hl.bind("SUPER + B", hl.dsp.exec_cmd(shell .. "bubble"))
hl.bind("SUPER + D", hl.dsp.exec_cmd(shell .. "show-desktop"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"))
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("enclave-terminal"))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd("enclave-terminal"))
hl.bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd("enclave-settings --page activity"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("Print", hl.dsp.exec_cmd("enclave-screenshot --full"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("enclave-screenshot"))

hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("SUPER + Up", hl.dsp.exec_cmd(shell .. "maximize"))
hl.bind("SUPER + Down", hl.dsp.exec_cmd(shell .. "minimize"))
hl.bind("SUPER + Left", function() enclave.snap("left") end)
hl.bind("SUPER + Right", function() enclave.snap("right") end)
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

for i = 1, 9 do
    hl.bind("SUPER + CTRL + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + CTRL + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

------------------------------------------------------------------ autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'QT_FORCE_STDERR_LOGGING=1 exec enclave-shell-run >\"${XDG_RUNTIME_DIR:-/tmp}/enclave-shell.log\" 2>&1'")
    hl.exec_cmd("mako")
    hl.exec_cmd("sh -c '[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ] && exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1'")
end)

------------------------------------------------------------------ the user's own
local home = getenv("HOME")
if home then
    local path = home .. "/.config/enclave/hyprland.lua"
    local f = io and io.open and io.open(path, "r")
    if f then
        f:close()
        local ok, err = pcall(dofile, path)
        if not ok then print("enclave: " .. tostring(err)) end
    end
end
