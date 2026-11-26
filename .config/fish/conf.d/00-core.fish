set -gx ADBLOCK 1
set -gx ASTRO_TELEMETRY_DISABLED 1
set -gx CARGO_NET_GIT_FETCH_WITH_CLI true
set -gx CHECKPOINT_DISABLE 1
set -gx DISABLE_OPENCOLLECTIVE 1
set -gx DO_NOT_TRACK 1
set -gx DOTNET_CLI_TELEMETRY_OPTOUT 1
set -gx EXPO_NO_TELEMETRY 1
set -gx GATSBY_TELEMETRY_DISABLED 1
set -gx GH_TELEMETRY false
set -gx HOMEBREW_NO_ANALYTICS 1
set -gx LANG "en_US.UTF-8"
set -gx LC_ALL "en_US.UTF-8"
set -gx NEXT_TELEMETRY_DISABLED 1
set -gx NUXT_TELEMETRY_DISABLED 1
set -gx PRISMA_DISABLE_TELEMETRY 1
set -gx T3CODE_OTEL_SDK_DISABLED true
set -gx T3CODE_TELEMETRY_ENABLED false
set -gx WRANGLER_SEND_METRICS false

# Session-scoped PATH: a global fish_user_paths shadows the universal one, so
# every fish_add_path in conf.d rebuilds PATH from this repo on each start
# instead of persisting into fish_variables, where entries for uninstalled
# tools lingered forever.
set -g fish_user_paths
fish_add_path /usr/local/bin /usr/local/sbin
fish_add_path $HOME/.local/bin

# System ssh-agent; same lookup as .profile.
if not test -S "$SSH_AUTH_SOCK"; and set -q XDG_RUNTIME_DIR
    for ssh_auth_sock in $XDG_RUNTIME_DIR/gcr/ssh $XDG_RUNTIME_DIR/ssh-agent.socket
        if test -S $ssh_auth_sock
            set -gx SSH_AUTH_SOCK $ssh_auth_sock
            break
        end
    end
end
