# headless X11 display from scripts/unstable/headless-x11.sh, unless a real
# display is already present
set -l headless_x11_env $HOME/.local/state/headless-x11/env
if not set -q DISPLAY; and not set -q WAYLAND_DISPLAY; and test -r $headless_x11_env
    for line in (string match -rv '^\s*(#|$)' <$headless_x11_env)
        set -gx (string split -m1 = -- $line)
    end
end
