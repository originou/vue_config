#!/bin/bash
# fzf popup to:
# 1) List / switch / create tmux sessions and windows (Sessions tab)
# 2) Move / detach current pane to popup, new session, or existing window (Pane tab)
#
# Tab navigation: ctrl-left / ctrl-right / tab / shift-tab
#
# Sessions tab:  ↵ = open window list (or create session if query matches nothing)
#                ctrl-x = kill the selected session
# Pane tab:      ↵ = break pane into popup, new session, or join target window
# Esc always goes back one step.

AGENTS="claude codex opencode agy"

WINDOW_FORMAT=$'#{window_index}\t#{?window_active,*, } #{window_index}: #{window_name}  [#{pane_current_command}]  #{window_panes}p'

icon() {
    case "$1" in
        claude)   printf '✻' ;;
        codex)    printf '❖' ;;
        opencode) printf '◆' ;;
        agy)      printf '▲' ;;
        agent)    printf '◇' ;;
        *)        printf '▪' ;;
    esac
}

# Base command of each agent
agent_base() {
    case "$1" in
        claude) printf 'claude --allow-dangerously-skip-permissions' ;;
        *)      printf '%s' "$1" ;;
    esac
}

# Wrap an agent command so its pane drops to a shell when it exits.
agent_wrap() {
    printf 'trap : INT; %s; exec %s' "$1" "$SHELL"
}

# Generic fzf menu. Args: prompt, header, then key/label pairs.
menu() {
    local prompt=$1 header=$2
    shift 2
    while [ $# -gt 0 ]; do printf '%s\t%s\n' "$1" "$2"; shift 2; done | \
        fzf --prompt="  $prompt: " \
            --delimiter=$'\t' \
            --with-nth=2 \
            --height=100% \
            --border=rounded \
            --header="$header  |  esc back" | cut -f1
}

# Free text prompt. Args: header, default label. Empty = default, Esc = fails.
ask_name() {
    local out
    out=$(fzf --print-query \
              --prompt="  name: " \
              --height=100% \
              --border=rounded \
              --header="$1  |  ↵ empty = $2  |  esc back" \
              < /dev/null)
    [ $? -eq 130 ] && return 1
    printf '%s' "$out" | head -1
}

# ---------------------------------------------------------------- claude history

claude_project_dir() {
    printf '%s/.claude/projects/%s' "$HOME" "$(printf '%s' "$1" | sed 's/[^a-zA-Z0-9]/-/g')"
}

conv_title() {
    local title
    title=$(grep -o '"customTitle":"[^"]*"' "$1" | tail -1 | cut -d'"' -f4)
    [ -z "$title" ] && title=$(grep -o '"aiTitle":"[^"]*"' "$1" | tail -1 | cut -d'"' -f4)
    [ -z "$title" ] && title=$(grep -m20 '"type":"user"' "$1" | jq -r '
        select(.isMeta != true) | .message.content
        | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join(" ")) end
        | select(startswith("<") | not)' 2>/dev/null | head -1 | cut -c1-80)
    printf '%s' "${title:-(empty)}"
}

list_conversations() {
    local f
    ls -t "$1"/*.jsonl 2>/dev/null | while read -r f; do
        printf '%s\t%s  %s\n' "$(basename "$f" .jsonl)" "$(date -r "$f" '+%Y-%m-%d %H:%M')" "$(conv_title "$f")"
    done
}

preview_conversation() {
    local f=$1
    head -c 20000 "$f" | grep -m1 '"cwd"' | jq -r '"dir:    \(.cwd)\nbranch: \(.gitBranch // "-")"' 2>/dev/null
    printf 'id:     %s\n\n' "$(basename "$f" .jsonl)"
    tail -n 400 "$f" | jq -r '
        select((.type == "user" or .type == "assistant") and .isMeta != true and .isSidechain != true)
        | .type as $t
        | (.message.content
           | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("\n")) end) as $c
        | select($c != "" and ($c | startswith("<") | not))
        | (if $t == "user" then "▶ you" else "◀ claude" end) + "\n" + $c + "\n"' 2>/dev/null | tail -n 80
}

# ---------------------------------------------------------------- directories

expand_home()   { printf '%s' "${1/#\~/$HOME}"; }
abbrev_home()   { local tilde="~"; printf '%s' "${1/#$HOME/$tilde}"; }

NEW_DIR="+ new: "

complete_dir() {
    local path base pat d hide=(-not -name '.*')
    path=$(expand_home "$1")
    if [[ -z $path || $path == */ ]]; then
        base=${path:-/}; pat=""
        [ -d "$base" ] && printf '%s\n' "$(abbrev_home "$base")"
    else
        base=$(dirname "$path"); base=${base%/}/; pat=$(basename "$path")
    fi
    if [ -d "$base" ]; then
        [[ $pat == .* ]] && hide=()
        find "$base" -mindepth 1 -maxdepth 1 -type d -iname "$pat*" "${hide[@]}" 2>/dev/null | sort |
        while read -r d; do printf '%s/\n' "$(abbrev_home "$d")"; done
    fi
    [[ -n $path && ! -e $path ]] && printf '\033[32m%s%s\033[0m\n' "$NEW_DIR" "$(abbrev_home "${path%/}")"
    return 0
}

preview_dir() {
    local dir
    if [[ $1 == "$NEW_DIR"* ]]; then
        printf '\033[32m↵ creates %s\033[0m\n' "${1#"$NEW_DIR"}"
        return 0
    fi
    dir=$(expand_home "$1")
    ls -A --color=always "$dir" 2>/dev/null
}

# ---------------------------------------------------------------- pane preview callback

preview_pane_target() {
    local key=$1 cur_pane=$2
    if [[ $key == action:* ]]; then
        printf '\033[1;36m=== Active Pane (%s) ===\033[0m\n\n' "$cur_pane"
        tmux capture-pane -ep -t "$cur_pane" 2>/dev/null
    elif [[ $key == win:* ]]; then
        local sess idx
        sess=$(cut -d: -f2 <<< "$key")
        idx=$(cut -d: -f3 <<< "$key")
        printf '\033[1;32m=== Target Window: %s:%s ===\033[0m\n\n' "$sess" "$idx"
        tmux capture-pane -ep -t "=$sess:$idx" 2>/dev/null
    fi
}

# Callbacks from fzf --preview / reload
case "$1" in
    --preview-conversation) preview_conversation "$2"; exit 0 ;;
    --complete-dir)         complete_dir "$2"; exit 0 ;;
    --preview-dir)          preview_dir "$2"; exit 0 ;;
    --preview-pane-target)  preview_pane_target "$2" "$3"; exit 0 ;;
esac

# ---------------------------------------------------------------- launch flow helpers

browse_dir() {
    local out query selected dir
    while :; do
        out=$(fzf --disabled \
                  --print-query \
                  --query="$(abbrev_home "$1")/" \
                  --with-shell='bash -c' \
                  --bind="start:reload:bash '$0' --complete-dir {q}" \
                  --bind="change:reload:bash '$0' --complete-dir {q}" \
                  --bind="tab:replace-query" \
                  --ansi \
                  --prompt="  dir: " \
                  --preview="bash '$0' --preview-dir {}" \
                  --preview-window=right:40%:border-left \
                  --height=100% \
                  --border=rounded \
                  --header="tab complete  |  ↵ use highlighted (or typed) dir, + new: creates it  |  esc back")
        [ $? -eq 130 ] && return 1
        query=$(printf '%s\n' "$out" | sed -n '1p')
        selected=$(printf '%s\n' "$out" | sed -n '2p')
        if [[ $selected == "$NEW_DIR"* ]]; then
            dir=$(expand_home "${selected#"$NEW_DIR"}")
            mkdir -p "$dir" && { printf '%s' "$dir"; return 0; }
            set -- "$(dirname "$dir")"; continue
        fi
        dir=$(expand_home "${selected:-$query}")
        dir=${dir%/}
        [ -d "${dir:-/}" ] && { printf '%s' "${dir:-/}"; return 0; }
        set -- "$(dirname "$dir")"
    done
}

frequent_dir() {
    zoxide query -l 2>/dev/null | while read -r d; do abbrev_home "$d"; echo; done | \
        fzf --prompt="  frequent: " \
            --with-shell='bash -c' \
            --preview="ls -A --color=always \"\$(sed 's|^~|$HOME|' <<< {})\"" \
            --preview-window=right:40%:border-left \
            --height=100% \
            --border=rounded \
            --header="zoxide  |  esc back" | { read -r d && expand_home "$d"; }
}

choose_dir() {
    local default=$1 header=$2 choice dir entries
    entries=(current "● $(abbrev_home "$default")")
    command -v zoxide >/dev/null && entries+=(frequent "★ frequent directories (zoxide)")
    entries+=(browse "… other directory (tab completion)")
    while :; do
        choice=$(menu "dir" "$header" "${entries[@]}")
        case "$choice" in
            "")       return 1 ;;
            current)  printf '%s' "$default"; return 0 ;;
            frequent) dir=$(frequent_dir) || continue ;;
            browse)   dir=$(browse_dir "$default") || continue ;;
        esac
        [ -n "$dir" ] && { printf '%s' "$dir"; return 0; }
    done
}

pick_conversation() {
    local proj
    proj=$(claude_project_dir "$1")
    list_conversations "$proj" | \
        fzf --prompt="  resume: " \
            --delimiter=$'\t' \
            --with-nth=2 \
            --with-shell='bash -c' \
            --preview="bash '$0' --preview-conversation '$proj/'{1}.jsonl" \
            --preview-window=right:55%:border-left:wrap:follow \
            --height=100% \
            --border=rounded \
            --header="$1  |  ↵ resume  |  esc back" | cut -f1 | grep .
}

agent_command() {
    local agent=$1 dir=$2 base mode id entries
    base=$(agent_base "$agent")
    case "$agent" in
        claude)   entries=(new "new" resume "resume…") ;;
        codex)    entries=(new "new" resume "resume…  (codex picker)") ;;
        opencode) entries=(new "new" new-auto "new  --auto"
                           resume "continue last session" resume-auto "continue last session  --auto") ;;
        agy)      entries=(new "new" new-auto "new  --dangerously-skip-permissions"
                           resume "continue last conversation"
                           resume-auto "continue last conversation  --dangerously-skip-permissions") ;;
    esac
    while :; do
        mode=$(menu "$agent" "$(icon "$agent") $agent" "${entries[@]}")
        case "$agent:$mode" in
            *:)                   return 1 ;;
            *:new)                printf '%s' "$base" ;;
            opencode:new-auto)    printf 'opencode --auto' ;;
            claude:resume)        id=$(pick_conversation "$dir") || continue
                                  printf '%s --resume %s' "$base" "$id" ;;
            codex:resume)         printf 'codex resume' ;;
            opencode:resume)      printf 'opencode --continue' ;;
            opencode:resume-auto) printf 'opencode --continue --auto' ;;
            agy:new-auto)         printf 'agy --dangerously-skip-permissions' ;;
            agy:resume)           printf 'agy --continue' ;;
            agy:resume-auto)      printf 'agy --continue --dangerously-skip-permissions' ;;
        esac
        return 0
    done
}

choose_launch() {
    local dir=$1 header=$2 top agent cmd a entries=()
    for a in $AGENTS; do entries+=("$a" "$(icon "$a") $a"); done
    while :; do
        top=$(menu "new" "$header" \
            tmux  "$(icon tmux) tmux" \
            agent "$(icon agent) agent")
        case "$top" in
            "")   return 1 ;;
            tmux) printf 'tmux\t'; return 0 ;;
        esac
        while :; do
            agent=$(menu "agent" "$header" "${entries[@]}")
            [ -z "$agent" ] && break
            cmd=$(agent_command "$agent" "$dir") || continue
            printf '%s\t%s' "$agent" "$cmd"
            return 0
        done
    done
}

new_flow() {
    local default=$1 header=$2 dir launch
    while :; do
        dir=$(choose_dir "$default" "$header") || return 1
        launch=$(choose_launch "$dir" "$header  |  $(abbrev_home "$dir")") || continue
        printf '%s\t%s\t%s' "${launch%%$'\t'*}" "$dir" "${launch#*$'\t'}"
        return 0
    done
}

pick_window() {
    local session=$1 choice target dir launch kind cmd name
    choice=$( {
        printf 'new\t+ new\n'
        tmux list-windows -t "=$session" -F "$WINDOW_FORMAT"
    } | fzf --prompt="  $session: " \
            --delimiter=$'\t' \
            --with-nth=2 \
            --with-shell='bash -c' \
            --preview="[[ {1} == new ]] || tmux capture-pane -ep -t '=$session:'{1}" \
            --preview-window=right:55%:border-left \
            --height=100% \
            --border=rounded \
            --header="↵ go to window  |  + new to create one  |  esc back" | cut -f1)

    case "$choice" in
        "")  exec bash "$0" ;;
        new) ;;
        *)   tmux switch-client -t "=$session:$choice"; exit 0 ;;
    esac

    dir=$(tmux display-message -p -t "=$session:" '#{pane_current_path}')
    launch=$(new_flow "$dir" "new window in \"$session\"") || pick_window "$session"
    IFS=$'\t' read -r kind dir cmd <<< "$launch"

    if [ "$kind" = tmux ]; then
        name=$(ask_name "new tmux window" auto) || pick_window "$session"
        target=$(tmux new-window -P -F '#{window_id}' -t "=$session:" -c "$dir" ${name:+-n "$name"})
    else
        name=$(ask_name "new window: $cmd" "$kind") || pick_window "$session"
        [[ $kind == claude && -n $name ]] && cmd+=" --name $(printf '%q' "$name")"
        target=$(tmux new-window -P -F '#{window_id}' -t "=$session:" -c "$dir" \
                     -n "${name:-$kind}" "$(agent_wrap "$cmd")")
    fi
    tmux switch-client -t "$target"
    exit 0
}

# ---------------------------------------------------------------- session listing

list_sessions() {
    local current
    current=$(tmux display-message -p '#{session_name}')
    tmux list-sessions -F "#{session_name}|#{@kind}|#{pane_current_command}|#{session_windows}|#{?session_attached,attached,}" 2>/dev/null |
    while IFS='|' read -r name kind cmd windows attached; do
        if [ -z "$kind" ]; then
            kind=tmux
            for a in $AGENTS; do [[ $cmd == "$a"* ]] && kind=$a; done
        fi
        mark=" "; [ "$name" = "$current" ] && mark="*"
        printf '%s\t%s %-24s %s %-9s %sw %s\n' \
            "$name" "$mark" "$name" "$(icon "$kind")" "$kind" "$windows" "$attached"
    done
}

# ---------------------------------------------------------------- pane targets listing

list_pane_targets() {
    local cur_pane=$1 cur_win
    cur_win=$(tmux display-message -t "$cur_pane" -p '#{window_id}' 2>/dev/null || echo "")

    printf 'action:popup\t🪟  [POPUP]          Extraire vers popup flottant i3\n'
    printf 'action:new\t➕  [NEW SESSION]    Extraire vers une nouvelle session\n'

    tmux list-windows -a -F "#{session_name}|#{window_id}|#{window_index}|#{window_name}|#{pane_current_command}|#{window_panes}" 2>/dev/null |
    while IFS='|' read -r sess wid idx wname cmd panes; do
        # Ne pas lister la fenêtre actuelle si elle n'a qu'un pane
        if [ "$wid" = "$cur_win" ]; then
            continue
        fi
        printf 'win:%s:%s\t➜   %-18s %s: %-14s [%s]  %sp\n' \
            "$sess" "$idx" "$sess" "$idx" "$wname" "$cmd" "$panes"
    done
}

extract_pane_to_session() {
    local pane_id=$1 session_name=$2
    local window_panes win_id target_win init_win pane_path
    window_panes=$(tmux display-message -t "$pane_id" -p '#{window_panes}')
    win_id=$(tmux display-message -t "$pane_id" -p '#{window_id}')
    pane_path=$(tmux display-message -t "$pane_id" -p '#{pane_current_path}')

    if [ "$window_panes" -gt 1 ]; then
        target_win=$(tmux break-pane -d -s "$pane_id" -P -F '#{window_id}')
    else
        target_win="$win_id"
    fi

    init_win=$(tmux new-session -d -P -F '#{window_id}' -s "$session_name" -c "$pane_path")
    tmux move-window -s "$target_win" -t "$session_name:"
    tmux kill-window -t "$init_win" 2>/dev/null || true
}

move_pane_as_window() {
    local pane_id=$1 target_session=$2
    local window_panes win_id
    window_panes=$(tmux display-message -t "$pane_id" -p '#{window_panes}')
    win_id=$(tmux display-message -t "$pane_id" -p '#{window_id}')

    if [ "$window_panes" -gt 1 ]; then
        local new_win
        new_win=$(tmux break-pane -d -s "$pane_id" -P -F '#{window_id}')
        tmux move-window -s "$new_win" -t "=$target_session:"
    else
        tmux move-window -s "$win_id" -t "=$target_session:"
    fi
}

# Directory chooser alone (current / zoxide / tab completion), for the polybar & $mod+Shift+a
# "Launch LLM" actions (i3/llm-launch.sh): prints the picked directory, fails on Esc
#   tmux-session-picker.sh --choose-dir DEFAULT [HEADER]
if [ "$1" = --choose-dir ]; then
    choose_dir "${2:-$HOME}" "${3:-directory}"
    exit
fi

# ---------------------------------------------------------------- main event loop

CURRENT_PANE="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null || echo "")}"
CURRENT_CMD=$(tmux display-message -t "$CURRENT_PANE" -p '#{pane_current_command}' 2>/dev/null || echo "shell")

TAB="sessions"

while :; do
    if [ "$TAB" = "sessions" ]; then
        RESULT=$(list_sessions | \
            fzf --prompt="  session: " \
                --print-query \
                --expect=ctrl-x,ctrl-left,ctrl-right,tab,btab,ctrl-h,ctrl-l \
                --delimiter=$'\t' \
                --with-nth=2 \
                --with-shell='bash -c' \
                --preview="tmux list-windows -t ={1} -F '$WINDOW_FORMAT' | cut -f2" \
                --preview-window=right:45%:border-left \
                --height=100% \
                --border=rounded \
                --header="[● Sessions]  [○ Pane (Move/Pop)]  |  ctrl-←/→ or tab: switch  |  ↵ select  |  ctrl-x kill")

        [ -z "$RESULT" ] && exit 0
        QUERY=$(printf '%s\n' "$RESULT" | sed -n '1p')
        KEY=$(printf '%s\n' "$RESULT" | sed -n '2p')
        SELECTED=$(printf '%s\n' "$RESULT" | sed -n '3p' | cut -f1)

        case "$KEY" in
            ctrl-left|ctrl-right|tab|btab|ctrl-h|ctrl-l)
                TAB="pane"
                continue
                ;;
            ctrl-x)
                [ -n "$SELECTED" ] && tmux kill-session -t "=$SELECTED"
                continue
                ;;
        esac

        [ -n "$SELECTED" ] && pick_window "$SELECTED"
        [ -z "$QUERY" ] && exit 0

        # Session name from query
        NAME=$(printf '%s' "$QUERY" | tr '.:' '__')
        tmux has-session -t "=$NAME" 2>/dev/null && pick_window "$NAME"

        DIR=$(tmux display-message -p '#{pane_current_path}')
        LAUNCH=$(new_flow "$DIR" "new session \"$NAME\"") || continue
        IFS=$'\t' read -r KIND DIR CMD <<< "$LAUNCH"

        if [ "$KIND" = tmux ]; then
            tmux new-session -d -s "$NAME" -c "$DIR"
        else
            [ "$KIND" = claude ] && CMD+=" --name $(printf '%q' "$NAME")"
            tmux new-session -d -s "$NAME" -n "$KIND" -c "$DIR" "$(agent_wrap "$CMD")"
        fi
        tmux set-option -t "=$NAME:" @kind "$KIND"
        tmux switch-client -t "=$NAME"
        exit 0

    else # TAB == "pane"
        RESULT=$(list_pane_targets "$CURRENT_PANE" | \
            fzf --prompt="  pane action: " \
                --print-query \
                --expect=ctrl-left,ctrl-right,tab,btab,ctrl-h,ctrl-l \
                --delimiter=$'\t' \
                --with-nth=2 \
                --with-shell='bash -c' \
                --preview="bash '$0' --preview-pane-target '{1}' '$CURRENT_PANE'" \
                --preview-window=right:45%:border-left \
                --height=100% \
                --border=rounded \
                --header="[○ Sessions]  [● Pane (Move/Pop)]  |  ctrl-←/→ or tab: switch  |  ↵ execute")

        [ -z "$RESULT" ] && exit 0
        QUERY=$(printf '%s\n' "$RESULT" | sed -n '1p')
        KEY=$(printf '%s\n' "$RESULT" | sed -n '2p')
        SELECTED=$(printf '%s\n' "$RESULT" | sed -n '3p' | cut -f1)

        case "$KEY" in
            ctrl-left|ctrl-right|tab|btab|ctrl-h|ctrl-l)
                TAB="sessions"
                continue
                ;;
        esac

        if [ "$SELECTED" = "action:popup" ]; then
            # Si l'utilisateur a tapé un nom dans fzf (autre que 'pop'/'popup'), on l'utilise, sinon auto
            q_clean=$(echo "$QUERY" | sed -E 's/^(pop(up)?)//i' | xargs)
            sess_name="${q_clean:-popup-${CURRENT_CMD}-$(date +%s | tail -c 4)}"
            sess_name=$(echo "$sess_name" | tr '.: ' '___')
            extract_pane_to_session "$CURRENT_PANE" "$sess_name"
            if command -v i3-msg >/dev/null 2>&1; then
                i3-msg "exec alacritty --class AlacrittyPopup -T '$sess_name' -e tmux attach-session -t $sess_name"
            else
                nohup alacritty --class AlacrittyPopup -T "$sess_name" -e tmux attach-session -t "$sess_name" </dev/null >/dev/null 2>&1 &
            fi
            exit 0
        elif [ "$SELECTED" = "action:new" ]; then
            q_clean=$(echo "$QUERY" | sed -E 's/^(new)//i' | xargs)
            sess_name="${q_clean:-${CURRENT_CMD}-$(date +%s | tail -c 4)}"
            sess_name=$(echo "$sess_name" | tr '.: ' '___')
            extract_pane_to_session "$CURRENT_PANE" "$sess_name"
            tmux switch-client -t "$sess_name"
            exit 0
        elif [[ "$SELECTED" == win:* ]]; then
            TARGET_SESS=$(cut -d: -f2 <<< "$SELECTED")
            TARGET_IDX=$(cut -d: -f3 <<< "$SELECTED")
            MODE=$(menu "join mode" "Move pane to $TARGET_SESS:$TARGET_IDX" \
                split-h "⬌ split horizontal (right)" \
                split-v "⬍ split vertical (bottom)" \
                window  "🗔 new window in $TARGET_SESS")
            case "$MODE" in
                split-h)
                    tmux join-pane -s "$CURRENT_PANE" -t "=$TARGET_SESS:$TARGET_IDX" -h
                    tmux switch-client -t "=$TARGET_SESS:$TARGET_IDX"
                    exit 0
                    ;;
                split-v)
                    tmux join-pane -s "$CURRENT_PANE" -t "=$TARGET_SESS:$TARGET_IDX" -v
                    tmux switch-client -t "=$TARGET_SESS:$TARGET_IDX"
                    exit 0
                    ;;
                window)
                    move_pane_as_window "$CURRENT_PANE" "$TARGET_SESS"
                    tmux switch-client -t "=$TARGET_SESS:"
                    exit 0
                    ;;
                *) continue ;;
            esac
        elif [ -n "$QUERY" ]; then
            sess_name=$(echo "$QUERY" | tr '.: ' '___')
            extract_pane_to_session "$CURRENT_PANE" "$sess_name"
            tmux switch-client -t "$sess_name"
            exit 0
        fi
    fi
done
