#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
#  Tahow Shell — Universal Installer & Updater
#  Designed for macOS-grade aesthetics on Hyprland (.conf & CachyOS .lua)
# ==============================================================================

readonly VERSION="1.3.0"
readonly REPO_URL="https://github.com/eduardoaugustolb/Tahow.git"
readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tahow"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly HYPR_DIR="$CONFIG_DIR/hypr"
readonly TAHOW_CONFIG_DIR="$CONFIG_DIR/tahow-shell"
readonly LOG_FILE="$STATE_DIR/install.log"
BACKUP_DIR=""
readonly TAHOW_SRC="$STATE_DIR/repo"

# Paleta Minimalista (Apple HIG Terminal Palette)
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'
readonly ACCENT='\033[38;5;39m'   # System Blue
readonly SUCCESS='\033[38;5;42m'  # System Green
readonly WARNING='\033[38;5;214m' # System Orange
readonly DANGER='\033[38;5;196m'  # System Red
readonly GRAY='\033[38;5;244m'

MODE="install"
case "${1:-}" in
    --update|-u)    MODE="update" ;;
    --uninstall)    MODE="uninstall" ;;
    "") ;;
    *) printf "Opção desconhecida: %s\n" "$1" >&2; exit 2 ;;
esac

BACKUP_CREATED=false
SUDO_KEEPALIVE_PID=""
MISSING_MANUAL_DEPS=()
SCALE_WARNING=false

# ------------------------------------------------------------------------------
# UI & Feedback Helpers
# ------------------------------------------------------------------------------
print_banner() {
    clear 2>/dev/null || true
    echo -e ""
    echo -e "  ${BOLD}  Tahow Shell${RESET} ${DIM}v${VERSION}${RESET}"
    echo -e "  ${GRAY}Liquid Glass & Spring Motion for Hyprland${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────────────────${RESET}"
    echo -e ""
}

step() {
    echo -e "  ${ACCENT}●${RESET} ${BOLD}$1${RESET}"
}

substep() {
    echo -e "    ${DIM}└─${RESET} ${GRAY}$1${RESET}"
}

success_item() {
    echo -e "    ${SUCCESS}✓${RESET} $1"
}

warn_item() {
    echo -e "    ${WARNING}!${RESET} $1"
}

run_with_spinner() {
    local label="$1"
    shift
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0

    "$@" >>"$LOG_FILE" 2>&1 &
    local pid=$!

    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r    ${ACCENT}%s${RESET} ${GRAY}%s${RESET}" "${frames[$i]}" "$label"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.08
    done

    local exit_code=0
    wait "$pid" || exit_code=$?
    tput cnorm 2>/dev/null || true

    if [[ $exit_code -eq 0 ]]; then
        printf "\r    ${SUCCESS}✓${RESET} %s\033[K\n" "$label"
    else
        printf "\r    ${DANGER}✕${RESET} %s\033[K\n" "$label"
        return $exit_code
    fi
}

cleanup_sudo() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Quickshell Runtime — sempre desanexado e idempotente
# ------------------------------------------------------------------------------
# `qs -p ... &` deixa o shell na tabela de jobs do terminal: o primeiro `exit`
# avisa e o segundo envia SIGHUP, derrubando a barra junto com o terminal.
# -d (--daemonize) desanexa com setsid e -n (--no-duplicate) torna chamadas
# repetidas seguras. O launcher versionado faz o mesmo e ainda confirma o boot.
start_tahow_shell() {
    local config_path="$TAHOW_CONFIG_DIR/shell.qml"
    local launcher="$TAHOW_CONFIG_DIR/bin/start-shell.sh"
    local log="${LOG_FILE:-/dev/null}"
    local qs_bin=""

    if [[ -x "$launcher" ]] && "$launcher" >>"$log" 2>&1; then
        return 0
    fi

    if command -v qs >/dev/null 2>&1; then
        qs_bin="qs"
    elif command -v quickshell >/dev/null 2>&1; then
        qs_bin="quickshell"
    else
        return 1
    fi

    "$qs_bin" -n -d -p "$config_path" >>"$log" 2>&1 || return 1
    return 0
}

# Mantém o autostart do Ryoku (config/autostart.lua) com o launcher desanexado.
configure_ryoku_autostart() {
    local file="$HYPR_DIR/config/autostart.lua"
    [[ -f "$file" ]] || return 0

    local launcher="${TAHOW_CONFIG_DIR//\'/\'\\\'\'}/bin/start-shell.sh"
    local line tmp
    printf -v line '    hl.exec_cmd("sh '\''%s'\''")' "$launcher"

    # Remove entradas antigas (inclusive o `qs -p ... &` que prendia o shell ao
    # terminal) e reinsere a canônica dentro do handler hyprland.start.
    tmp=$(mktemp "${file}.XXXXXX")
    awk -v line="$line" '
        /hl\.exec_cmd/ && /tahow-shell\// { next }
        { print }
        !inserted && /hl\.on\([[:space:]]*"hyprland\.start"/ { print line; inserted = 1 }
        END { if (!inserted) print line }
    ' "$file" > "$tmp"
    if cmp -s "$file" "$tmp"; then
        rm -f "$tmp"
    else
        mv "$tmp" "$file"
        success_item "Autostart do desktop atualizado em ${DIM}config/autostart.lua${RESET}"
    fi
}

# ------------------------------------------------------------------------------
# Fallback & Rollback Automático
# ------------------------------------------------------------------------------
rollback() {
    local exit_code="${1:-$?}"
    trap - ERR INT TERM
    cleanup_sudo
    tput cnorm 2>/dev/null || true
    echo -e ""
    echo -e "  ${DANGER}✕  A operação foi interrompida (código: ${exit_code}).${RESET}"

    if [[ "$BACKUP_CREATED" == true && -d "$BACKUP_DIR" ]]; then
        substep "Restaurando estado anterior automaticamente..."
        # The backup can include a plugin still mapped by the compositor.
        local restore=(rsync -a --ignore-times -- "$BACKUP_DIR/" "$CONFIG_DIR/")
        if ! command -v rsync &>/dev/null; then
            restore=(cp -a --remove-destination -- "$BACKUP_DIR/." "$CONFIG_DIR/")
        fi
        if "${restore[@]}"; then
            success_item "Arquivos do backup repostos; arquivos novos podem permanecer."
        else
            warn_item "Restauração incompleta. Backup disponível em $BACKUP_DIR"
        fi
    fi

    if [[ -f "$LOG_FILE" ]]; then
        local display_log="${LOG_FILE/#$HOME/\~}"
        echo -e ""
        echo -e "  ${DIM}Últimas linhas do diagnóstico ($display_log):${RESET}"
        echo -e "${GRAY}$(tail -n 6 "$LOG_FILE" | sed 's/^/    /')${RESET}"
    fi
    echo -e ""
    exit "$exit_code"
}

trap rollback ERR
trap 'rollback 130' INT
trap 'rollback 143' TERM
trap cleanup_sudo EXIT

# ------------------------------------------------------------------------------
# Validação de Privilégios (Exige sudo sem rodar como root)
# ------------------------------------------------------------------------------
require_privileges() {
    if [[ $EUID -eq 0 ]]; then
        print_banner
        echo -e "  ${DANGER}✕  Não execute este script diretamente como root (sudo ./install.sh).${RESET}"
        echo -e "  ${GRAY}   Execute como seu usuário normal — o instalador solicitará${RESET}"
        echo -e "  ${GRAY}   a senha do sudo automaticamente para instalar pacotes:${RESET}"
        echo -e ""
        echo -e "     ${BOLD}./install.sh${RESET}"
        echo -e ""
        exit 1
    fi

    [[ "$MODE" == "update" ]] && return 0

    if ! command -v sudo &>/dev/null; then
        echo -e "  ${DANGER}✕  O comando 'sudo' não está disponível neste sistema.${RESET}"
        exit 1
    fi

    step "Autenticação necessária"
    substep "Solicitando permissão administrativa para gerenciar dependências..."
    if ! sudo -v; then
        echo -e "  ${DANGER}✕  Autenticação sudo falhou. Instalação cancelada.${RESET}"
        exit 1
    fi

    ( while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    success_item "Permissão administrativa confirmada para ${BOLD}${USER}${RESET}"
}

# ------------------------------------------------------------------------------
# Desinstalação (--uninstall)
# ------------------------------------------------------------------------------
uninstall_tahow() {
    print_banner
    step "Removendo Tahow Shell"

    if command -v hyprctl &>/dev/null && [[ -f "$TAHOW_CONFIG_DIR/native/live-glass.so" ]]; then
        hyprctl plugin unload "$TAHOW_CONFIG_DIR/native/live-glass.so" >/dev/null 2>&1 || true
    fi
    if command -v qs &>/dev/null; then
        qs -p "$TAHOW_CONFIG_DIR/shell.qml" kill >/dev/null 2>&1 || true
    fi

    [[ -f "$HYPR_DIR/hyprland.lua" ]] && sed -i '/require("tahow\.init")/d' "$HYPR_DIR/hyprland.lua"
    if [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
        local escaped_hypr_dir
        escaped_hypr_dir=$(printf '%s' "$HYPR_DIR" | sed 's/[][\\.^$*|]/\\&/g')
        sed -i -e '\|^source = ~/\.config/hypr/tahow/tahow\.conf$|d' \
            -e "\\|^source = $escaped_hypr_dir/tahow/tahow\\.conf\$|d" "$HYPR_DIR/hyprland.conf"
    fi

    if [[ -f "$HYPR_DIR/config/autostart.lua" ]]; then
        sed -i -e '/tahow-shell\/shell\.qml/d' -e '/tahow-shell\/bin\/start-shell\.sh/d' "$HYPR_DIR/config/autostart.lua"
        sed -i -E 's/^(-- \[TAHOW_DISABLED\] )+//' "$HYPR_DIR/config/autostart.lua"
    fi

    rm -f "$HYPR_DIR/tahow/init.lua" "$HYPR_DIR/tahow/tahow.conf"
    success_item "Integração do Hyprland removida. Preferências e backups do Tahow foram preservados."

    echo -e ""
    echo -e "  ${SUCCESS}${BOLD}Desinstalação concluída.${RESET} ${GRAY}Recarregue o Hyprland para aplicar.${RESET}"
    echo -e ""
    exit 0
}

[[ "$MODE" == "uninstall" ]] && uninstall_tahow

# ------------------------------------------------------------------------------
# Etapas Principais
# ------------------------------------------------------------------------------
init_environment() {
    mkdir -p "$STATE_DIR" "$HYPR_DIR"
    BACKUP_DIR=$(mktemp -d "$STATE_DIR/backup_XXXXXXXX")
    : > "$LOG_FILE"

    step "Preparando ambiente"
    for dir in hypr tahow-shell noctalia quickshell waybar autostart gtk-3.0 gtk-4.0; do
        [[ -d "$CONFIG_DIR/$dir" ]] && cp -rf "$CONFIG_DIR/$dir" "$BACKUP_DIR/"
    done
    BACKUP_CREATED=true
    success_item "Snapshot de segurança salvo em ${DIM}${BACKUP_DIR/#$HOME/\~}${RESET}"
}

install_dependencies() {
    [[ "$MODE" == "update" ]] && return 0

    step "Verificando dependências do sistema"
    local distro="unknown"
    [[ -f /etc/os-release ]] && { . /etc/os-release; distro="${ID:-unknown}"; }

    case "$distro" in
        cachyos|arch|endeavouros|manjaro)
            local official_deps=(git jq rsync imagemagick papirus-icon-theme inter-font)
            run_with_spinner "Instalando pacotes oficiais via pacman ($distro)" \
                sudo pacman -S --needed --noconfirm "${official_deps[@]}"

            if ! command -v qs &>/dev/null && ! command -v quickshell &>/dev/null; then
                local aur_helper=""
                for h in paru yay; do command -v "$h" &>/dev/null && { aur_helper="$h"; break; }; done

                if [[ -n "$aur_helper" ]]; then
                    if ! run_with_spinner "Instalando Quickshell via $aur_helper" \
                        "$aur_helper" -S --needed --noconfirm quickshell-git; then
                        warn_item "Falha ao compilar quickshell-git automaticamente"
                        MISSING_MANUAL_DEPS+=("quickshell-git")
                    fi
                else
                    warn_item "Instale o 'quickshell' manualmente (paru/yay não encontrado)"
                    MISSING_MANUAL_DEPS+=("quickshell")
                fi
            else
                success_item "Runtime Quickshell já instalado"
            fi
            ;;
        fedora)
            run_with_spinner "Instalando pacotes base via dnf (Fedora)" \
                sudo dnf install -y git jq rsync ImageMagick papirus-icon-theme rsms-inter-fonts
            command -v qs &>/dev/null || MISSING_MANUAL_DEPS+=("quickshell")
            ;;
        ubuntu|debian|pop)
            run_with_spinner "Instalando pacotes base via apt ($distro)" \
                bash -c "sudo apt-get update -qq && sudo apt-get install -y -qq git jq rsync imagemagick papirus-icon-theme fonts-inter"
            command -v qs &>/dev/null || MISSING_MANUAL_DEPS+=("quickshell")
            ;;
        *)
            warn_item "Distribuição '${distro}' em modo fallback genérico"
            for bin in git jq magick qs; do
                command -v "$bin" &>/dev/null || MISSING_MANUAL_DEPS+=("$bin")
            done
            ;;
    esac
}

sync_repository() {
    step "Obtendo Tahow Shell"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ "$script_dir" != "$(realpath -m "$TAHOW_SRC")" && -f "$script_dir/shell/shell.qml" ]]; then
        if [[ -d "$script_dir/.git" && "$MODE" == "update" ]]; then
            run_with_spinner "Atualizando repositório Git local" git -C "$script_dir" pull --ff-only
        fi
        mkdir -p "$TAHOW_SRC"
        for dir in shell integrations locales native tools; do
            mkdir -p "$TAHOW_SRC/$dir"
            rsync -a --delete "$script_dir/$dir/" "$TAHOW_SRC/$dir/"
        done
        cp -f "$script_dir"/{package.json,LICENSE,NOTICE.md} "$TAHOW_SRC/"
        success_item "Usando código-fonte local em ${DIM}${script_dir/#$HOME/\~}${RESET}"
    elif [[ -d "$TAHOW_SRC/.git" ]]; then
        run_with_spinner "Atualizando código-fonte local" git -C "$TAHOW_SRC" pull --ff-only
    else
        run_with_spinner "Baixando repositório oficial" git clone --depth=1 "$REPO_URL" "$TAHOW_SRC"
    fi
}

build_and_deploy_assets() {
    step "Compilando shaders e provider nativo"

    mkdir -p "$TAHOW_CONFIG_DIR/native"

    # Compila shaders .qsb se Bun estiver disponível
    if command -v bun &>/dev/null && [[ -f "$TAHOW_SRC/tools/build-shaders.ts" ]]; then
        run_with_spinner "Compilando shaders Liquid Glass (.qsb)" \
            bun "$TAHOW_SRC/tools/build-shaders.ts" || warn_item "Usando shaders .qsb pré-compilados"
    fi

    # Sincroniza arquivos do shell preservando configurações e histórico do usuário
    if [[ -d "$TAHOW_SRC/shell" ]]; then
        if command -v rsync &>/dev/null; then
            rsync -a --delete \
                --exclude='settings.json' \
                --exclude='launcher-history.json' \
                --exclude='native' \
                "$TAHOW_SRC/shell/" "$TAHOW_CONFIG_DIR/"
        else
            cp -rf "$TAHOW_SRC/shell"/* "$TAHOW_CONFIG_DIR/"
        fi
        success_item "Arquivos do shell sincronizados em ${DIM}~/.config/tahow-shell/${RESET}"
    fi

    # Calibra óptica Liquid Glass padrão se o usuário ainda não tiver settings.json
    if [[ ! -e "$TAHOW_CONFIG_DIR/settings.json" && ! -e "$CONFIG_DIR/tahoe-shell/settings.json" ]]; then
        cat << 'EOF' > "$TAHOW_CONFIG_DIR/settings.json"
{
    "liquidGlass": true,
    "screenCapture": true,
    "style": "glass",
    "ior": 1.52,
    "dispersion": 0.14,
    "bezel": 16,
    "thickness": 28,
    "rimStrength": 0.9,
    "frost": 10,
    "glassOpacity": 0.45,
    "glassRim": true,
    "innerShadow": 0.35
}
EOF
        success_item "Perfil óptico Liquid Glass inicial configurado"
    fi

    # Compila o provider nativo C++ (refração em tempo real no compositor)
    if command -v bun &>/dev/null && [[ -f "$TAHOW_SRC/native/live-glass/build.ts" ]]; then
        if run_with_spinner "Compilando provider nativo tahow-live-glass (C++)" \
            bun "$TAHOW_SRC/native/live-glass/build.ts"; then
            local built_so plugin_path reply
            built_so=$(find "$TAHOW_SRC/native/live-glass/build" -name "*.so" 2>/dev/null | head -n 1 || true)
            if [[ -n "$built_so" ]]; then
                # Replacing the inode keeps the running compositor's mapping intact.
                plugin_path="$TAHOW_CONFIG_DIR/native/live-glass.so"
                rsync -a --ignore-times -- "$built_so" "$plugin_path"
                success_item "Provider nativo instalado em ${DIM}~/.config/tahow-shell/native/live-glass.so${RESET}"
                if command -v hyprctl >/dev/null && hyprctl monitors -j >/dev/null 2>&1; then
                    # A fresh session may not have the plugin loaded yet.
                    hyprctl plugin unload "$plugin_path" >>"$LOG_FILE" 2>&1 || true
                    if reply=$(hyprctl plugin load "$plugin_path" 2>&1) && [[ "$reply" == ok ]]; then
                        success_item "Provider nativo recarregado no Hyprland"
                    else
                        printf '%s\n' "$reply" >>"$LOG_FILE"
                        warn_item "Provider atualizado no disco, mas a recarga falhou. Consulte o log ou reinicie a sessão."
                    fi
                fi
            fi
        else
            warn_item "Provider nativo não compilado — usando fallback QSB/snapshot"
        fi
    fi
}

configure_hyprland() {
    step "Configurando Hyprland, atalhos e física Spring"

    # Verifica escala fracionária (live-glass exige scale 1)
    if command -v hyprctl &>/dev/null && command -v jq &>/dev/null; then
        if hyprctl monitors -j 2>/dev/null | jq -e '.[] | select(.scale != 1)' >/dev/null 2>&1; then
            SCALE_WARNING=true
        fi
    fi

    # Integração Hyprland Lua (CachyOS) vs .conf tradicional
    mkdir -p "$HYPR_DIR/tahow"
    local shortcuts key action description
    if [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
        shortcuts="$HYPR_DIR/tahow/shortcuts.lua"
        if [[ ! -e "$HYPR_DIR/tahow/shortcuts.lua" ]]; then
            cat << 'EOF' > "$HYPR_DIR/tahow/shortcuts.lua"
-- Edit the key combinations here and reload Hyprland.
local config = os.getenv("XDG_CONFIG_HOME")
if not config or config == "" then config = os.getenv("HOME") .. "/.config" end
local shell = (config .. "/tahow-shell/shell.qml"):gsub("'", "'\\''")
local ipc = "qs -p '" .. shell .. "' ipc call tahoe "
hl.bind("SUPER + Space", hl.dsp.exec_cmd(ipc .. "launcher"))
hl.bind("SUPER + SHIFT + Space", hl.dsp.exec_cmd(ipc .. "settings"))
EOF
        fi
        # Upgrade generated actions without changing personalized keys.
        sed -E -i \
            -e "s@^local ipc = .*shell \.\. .*ipc call tahoe \"\$@local ipc = \"sh '\" .. shell:gsub(\"/shell%.qml\$\", \"/bin/shortcut-ipc.sh\") .. \"' \"@" \
            -e "s@^local ipc = \"sh \"( \.\. shell:gsub\(\"/shell%\.qml\\\$\", \"/bin/shortcut-ipc\.sh\"\) \.\.) \" \"\$@local ipc = \"sh '\"\1 \"' \"@" \
            -e 's/(hl\.dsp\.exec_cmd\(ipc \.\. "launcher"\))\)$/\1, { description = "Spotlight" })/' \
            -e 's/(hl\.dsp\.exec_cmd\(ipc \.\. "settings"\))\)$/\1, { description = "Open preferences" })/' \
            "$shortcuts"
        if grep -q '^local ipc = ' "$shortcuts"; then
            while read -r key action description; do
                if ! grep -Eiq '^[[:space:]]*[^-[:space:]].*("SUPER[[:space:]]*[+][[:space:]]*'"$key"'"|ipc \.\. "'"$action"'")' "$shortcuts"; then
                    printf '\nhl.bind("SUPER + %s", hl.dsp.exec_cmd(ipc .. "%s"), { description = "%s" })\n' \
                        "$key" "$action" "$description" >> "$shortcuts"
                fi
            done <<< $'V clipboard Clipboard\nperiod emojis Emojis'
        fi
        sed -i '/^hl.bind("Print",.*grim .*wl-copy.*description = "Screenshot"/c\hl.bind("Print", hl.dsp.exec_cmd(ipc .. "capture"), { description = "Screenshot" })' "$shortcuts"
        if [[ -s "$shortcuts" ]] && ! grep -Eiq '^[[:space:]]*hl\.bind[[:space:]]*\([[:space:]]*"Print"' "$shortcuts"; then
            cat << 'EOF' >> "$shortcuts"

hl.unbind("Print")
hl.bind("Print", hl.dsp.exec_cmd(ipc .. "capture"), { description = "Screenshot" })
EOF
        fi
        # A duplicate toggle can open and immediately close the palette.
        if grep -Eq '^hl\.bind\("[^"]+", hl\.dsp\.exec_cmd\(ipc \.\. "launcher"\),' "$HYPR_DIR/tahow/shortcuts.lua"; then
            sed -E -i \
                -e '1i local function bindLauncher(key, action, options)\n    hl.unbind(key)\n    hl.bind(key, action, options)\nend' \
                -e '/^hl\.bind\("[^"]+", hl\.dsp\.exec_cmd\(ipc \.\. "launcher"\),/s/^hl\.bind/bindLauncher/' \
                "$HYPR_DIR/tahow/shortcuts.lua"
        fi
        if [[ ! -e "$HYPR_DIR/tahow/window-shortcuts.lua" ]]; then
            cat << 'EOF' > "$HYPR_DIR/tahow/window-shortcuts.lua"
hl.bind("SUPER + Left", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("SUPER + Right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("SUPER + SHIFT + Left", hl.dsp.window.move({ workspace = "r-1", follow = true }))
hl.bind("SUPER + SHIFT + Right", hl.dsp.window.move({ workspace = "r+1", follow = true }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
EOF
        fi
        if [[ ! -e "$HYPR_DIR/tahow/workspace-shortcuts.lua" ]]; then
            cat << 'EOF' > "$HYPR_DIR/tahow/workspace-shortcuts.lua"
for workspace = 1, 10 do
    hl.bind("SUPER + " .. (workspace % 10), hl.dsp.focus({ workspace = tostring(workspace) }))
end
EOF
        fi
        if ! grep -Fq 'hl.dsp.window.move' "$HYPR_DIR/tahow/workspace-shortcuts.lua"; then
            sed -i '/^    hl\.bind("SUPER + " \.\. (workspace % 10), hl\.dsp\.focus({ workspace = tostring(workspace) })/a\    hl.bind("SUPER + SHIFT + code:" .. (9 + workspace), hl.dsp.window.move({ workspace = tostring(workspace), follow = true }), { description = "Move window to workspace " .. workspace })' \
                "$HYPR_DIR/tahow/workspace-shortcuts.lua"
        fi
        if ! grep -Fq 'hl.unbind("SUPER + SHIFT + code:" .. (9 + workspace))' "$HYPR_DIR/tahow/workspace-shortcuts.lua"; then
            sed -i '/^    hl\.bind("SUPER + SHIFT + code:" \.\. (9 + workspace), hl\.dsp\.window\.move({ workspace = tostring(workspace), follow = true })/i\    hl.unbind("SUPER + SHIFT + " .. (workspace % 10))\n    hl.unbind("SUPER + SHIFT + code:" .. (9 + workspace))' \
                "$HYPR_DIR/tahow/workspace-shortcuts.lua"
        fi
        sed -E -i \
            -e 's/(hl\.dsp\.focus\(\{ workspace = "r-1" \}\))\)$/\1, { description = "Previous workspace" })/' \
            -e 's/(hl\.dsp\.focus\(\{ workspace = "r\+1" \}\))\)$/\1, { description = "Next workspace" })/' \
            -e 's/(hl\.dsp\.window\.move\(\{ workspace = "r-1", follow = true \}\))\)$/\1, { description = "Move window to previous workspace" })/' \
            -e 's/(hl\.dsp\.window\.move\(\{ workspace = "r\+1", follow = true \}\))\)$/\1, { description = "Move window to next workspace" })/' \
            -e 's/(hl\.dsp\.window\.fullscreen\(\{ mode = "fullscreen", action = "toggle" \}\))\)$/\1, { description = "Toggle fullscreen" })/' \
            -e '/hl\.dispatch\(hl\.dsp\.window\.alter_zorder\(\{ mode = "top" \}\)\)/ {n; s/^end\)$/end, { description = "Switch windows" })/; }' \
            "$HYPR_DIR/tahow/window-shortcuts.lua"
        sed -E -i \
            's/(hl\.dsp\.focus\(\{ workspace = tostring\(workspace\) \}\))\)$/\1, { description = "Go to workspace " .. workspace })/' \
            "$HYPR_DIR/tahow/workspace-shortcuts.lua"
        cat << 'EOF' > "$HYPR_DIR/tahow/init.lua"
-- Tahow Liquid Glass & Spring Physics (Auto-generated)
hl.curve("tahowSpring", { type = "spring", mass = 1, stiffness = 360, dampening = 24 })
hl.curve("tahowBubble", { type = "spring", mass = 0.9, stiffness = 420, dampening = 22 })
hl.curve("tahowSmooth", { type = "bezier", points = { {0.16, 1.0}, {0.3, 1.0} } })

hl.animation({ leaf = "windowsIn",          enabled = true, speed = 4, spring = "tahowBubble", style = "popin 82%" })
hl.animation({ leaf = "windowsOut",         enabled = true, speed = 3, bezier = "tahowSmooth", style = "popin 88%" })
hl.animation({ leaf = "windowsMove",        enabled = true, speed = 4, spring = "tahowSpring" })
hl.animation({ leaf = "workspaces",         enabled = true, speed = 5, bezier = "tahowSmooth", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 4, spring = "tahowBubble", style = "slidevert" })

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 1,
        col = {
            active_border = {
                colors = { "rgba(ffffff66)", "rgba(ffffff14)" },
                angle = 45,
            },
            inactive_border = "rgba(ffffff18)",
        },
    },
    decoration = {
        rounding = 18,
        active_opacity = 0.92,
        inactive_opacity = 0.86,
        blur = {
            enabled = true,
            size = 12,
            passes = 4,
            noise = 0.012,
            contrast = 1.08,
            brightness = 1.12,
            vibrancy = 0.42,
        },
        shadow = {
            enabled = true,
            range = 30,
            render_power = 3,
            color = "rgba(00000066)",
        },
    },
})

require("tahow.shortcuts")
require("tahow.window-shortcuts")
require("tahow.workspace-shortcuts")

hl.on("hyprland.start", function ()
    local config = os.getenv("XDG_CONFIG_HOME")
    if not config or config == "" then config = os.getenv("HOME") .. "/.config" end
    local root = (config .. "/tahow-shell"):gsub("'", "'\\''")
    local plugin_path = config .. "/tahow-shell/native/live-glass.so"
    local f = io.open(plugin_path, "r")
    if f then
        f:close()
        hl.exec_cmd("hyprctl plugin load '" .. root .. "/native/live-glass.so'")
    end
    hl.exec_cmd("sh '" .. root .. "/bin/start-shell.sh'")
end)
EOF
        grep -q 'require("tahow.init")' "$HYPR_DIR/hyprland.lua" || echo 'require("tahow.init")' >> "$HYPR_DIR/hyprland.lua"
        success_item "Módulo Lua e física Spring integrados em ${DIM}hyprland.lua${RESET}"
    else
        shortcuts="$HYPR_DIR/tahow/shortcuts.conf"
        local shell_path="${TAHOW_CONFIG_DIR//\'/\'\\\'\'}/shell.qml"
        if [[ ! -e "$HYPR_DIR/tahow/shortcuts.conf" ]]; then
            cat << EOF > "$HYPR_DIR/tahow/shortcuts.conf"
# Edit the key combinations here and reload Hyprland.
bind = SUPER, Space, exec, qs -p '$shell_path' ipc call tahoe launcher
bind = SUPER SHIFT, Space, exec, qs -p '$shell_path' ipc call tahoe settings
EOF
        fi
        if [[ -s "$shortcuts" ]]; then
            sed -i '/^bindd = , Print, Screenshot, exec, .*grim .*wl-copy/d' "$shortcuts"
            if ! grep -Eiq '^[[:space:]]*bind[^=]*=[[:space:]]*,[[:space:]]*Print[[:space:]]*,' "$shortcuts"; then
                printf "\nbindd = , Print, Screenshot, exec, sh '%s/bin/shortcut-ipc.sh' capture\n" "${shell_path%/shell.qml}" >> "$shortcuts"
            fi
            while read -r key action description; do
                if ! grep -Eiq '^[[:space:]]*bind[^=]*=[[:space:]]*(SUPER|MOD4)[[:space:]]*,[[:space:]]*'"$key"'[[:space:]]*,|^[[:space:]]*bind[^=]*=.*(shortcut-ipc\.sh|ipc call tahoe).* '"$action"'[[:space:]]*$' "$shortcuts"; then
                    printf "\nbindd = SUPER, %s, %s, exec, sh '%s/bin/shortcut-ipc.sh' %s\n" \
                        "$key" "$description" "${shell_path%/shell.qml}" "$action" >> "$shortcuts"
                fi
            done <<< $'V clipboard Clipboard\nperiod emojis Emojis'
        fi
        if [[ ! -e "$HYPR_DIR/tahow/window-shortcuts.conf" ]]; then
            cat << 'EOF' > "$HYPR_DIR/tahow/window-shortcuts.conf"
bind = SUPER, Left, workspace, r-1
bind = SUPER, Right, workspace, r+1
bind = SUPER SHIFT, Left, movetoworkspace, r-1
bind = SUPER SHIFT, Right, movetoworkspace, r+1
bind = SUPER, F, fullscreen, 0
bind = ALT, Tab, cyclenext
bind = ALT, Tab, alterzorder, top
EOF
        fi
        local workspace workspace_shortcuts="$HYPR_DIR/tahow/workspace-shortcuts.conf"
        if [[ ! -e "$workspace_shortcuts" ]]; then
            for workspace in {1..10}; do
                printf 'bind = SUPER, %s, workspace, %s\n' "$((workspace % 10))" "$workspace"
            done > "$workspace_shortcuts"
        fi
        if [[ -s "$workspace_shortcuts" ]] && ! grep -q 'movetoworkspace' "$workspace_shortcuts"; then
            for workspace in {1..10}; do
                printf 'bindd = SUPER SHIFT, code:%s, Move window to workspace %s, movetoworkspace, %s\n' \
                    "$((9 + workspace))" "$workspace" "$workspace"
            done >> "$workspace_shortcuts"
        fi
        sed -E -i \
            -e "s@^bind( = [^,]+, [^,]+), exec, qs -p '(.+)/shell.qml' ipc call tahoe launcher\$@bindd\1, Spotlight, exec, sh '\2/bin/shortcut-ipc.sh' launcher@" \
            -e "s@^bind( = [^,]+, [^,]+), exec, qs -p '(.+)/shell.qml' ipc call tahoe settings\$@bindd\1, Open preferences, exec, sh '\2/bin/shortcut-ipc.sh' settings@" \
            "$HYPR_DIR/tahow/shortcuts.conf"
        sed -E -i \
            -e 's/^bind( = [^,]+, [^,]+), workspace, r-1$/bindd\1, Previous workspace, workspace, r-1/' \
            -e 's/^bind( = [^,]+, [^,]+), workspace, r\+1$/bindd\1, Next workspace, workspace, r+1/' \
            -e 's/^bind( = [^,]+, [^,]+), movetoworkspace, r-1$/bindd\1, Move window to previous workspace, movetoworkspace, r-1/' \
            -e 's/^bind( = [^,]+, [^,]+), movetoworkspace, r\+1$/bindd\1, Move window to next workspace, movetoworkspace, r+1/' \
            -e 's/^bind( = [^,]+, [^,]+), fullscreen, 0$/bindd\1, Toggle fullscreen, fullscreen, 0/' \
            -e 's/^bind( = [^,]+, [^,]+), cyclenext$/bindd\1, Switch windows, cyclenext,/' \
            "$HYPR_DIR/tahow/window-shortcuts.conf"
        sed -E -i 's/^bind( = [^,]+, [^,]+), workspace, ([0-9]+)$/bindd\1, Go to workspace \2, workspace, \2/' \
            "$HYPR_DIR/tahow/workspace-shortcuts.conf"
        for workspace in {1..10}; do
            if ! grep -Fxq "unbind = SUPER SHIFT, code:$((9 + workspace))" "$workspace_shortcuts"; then
                sed -i "/^bindd = SUPER SHIFT, code:$((9 + workspace)), Move window to workspace $workspace, movetoworkspace, $workspace\$/i\unbind = SUPER SHIFT, $((workspace % 10))\nunbind = SUPER SHIFT, code:$((9 + workspace))" \
                    "$workspace_shortcuts"
            fi
        done
        cat << 'EOF' > "$HYPR_DIR/tahow/tahow.conf"
# Tahow Liquid Glass & Spring Motion (Auto-generated)
bezier = tahowBubble, 0.16, 1.0, 0.3, 1.0
bezier = tahowSpring, 0.22, 1.15, 0.36, 1.0

animation = windowsIn,   1, 4.5, tahowSpring, popin 82%
animation = windowsOut,  1, 3.8, tahowBubble, popin 88%
animation = windowsMove, 1, 4.5, tahowBubble
animation = workspaces,  1, 4.8, tahowBubble, slide

general {
    gaps_in = 6
    gaps_out = 12
    border_size = 1
    col.active_border = rgba(ffffff66) rgba(ffffff14) 45deg
    col.inactive_border = rgba(ffffff18)
}

decoration {
    rounding = 18
    active_opacity = 0.92
    inactive_opacity = 0.86
    blur {
        enabled = true
        size = 12
        passes = 4
        noise = 0.012
        contrast = 1.08
        brightness = 1.12
        vibrancy = 0.42
    }
}

exec-once = hyprctl plugin load ~/.config/tahow-shell/native/live-glass.so
EOF
        printf "exec-once = sh '%s'\n" "${shell_path%/shell.qml}/bin/start-shell.sh" >> "$HYPR_DIR/tahow/tahow.conf"
        printf 'source = %s\n' "$HYPR_DIR"/tahow/{shortcuts,window-shortcuts,workspace-shortcuts}.conf >> "$HYPR_DIR/tahow/tahow.conf"
        touch "$HYPR_DIR/hyprland.conf"
        grep -Fqx -e "source = $HYPR_DIR/tahow/tahow.conf" -e 'source = ~/.config/hypr/tahow/tahow.conf' "$HYPR_DIR/hyprland.conf" ||
            printf '\nsource = %s/tahow/tahow.conf\n' "$HYPR_DIR" >> "$HYPR_DIR/hyprland.conf"
        success_item "Configuração modular vinculada em ${DIM}hyprland.conf${RESET}"
    fi

    configure_ryoku_autostart

    # Quickshell reloads the deployed QML in place when its files change.
    if command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1; then
        if start_tahow_shell; then
            success_item "Sessão ativa recarregada com a nova versão"
        else
            warn_item "Shell não iniciado agora; ele subirá no próximo login"
        fi
    fi
}

print_summary() {
    local display_log="${LOG_FILE/#$HOME/\~}"

    local script_ref
    if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
        script_ref="${BASH_SOURCE[0]}"
    else
        script_ref="curl -fsSL https://tahow.eduardoaugusto.work/install.sh | bash -s --"
    fi

    local activate_cmd
    printf -v activate_cmd 'hyprctl reload && sh %q' "$TAHOW_CONFIG_DIR/bin/start-shell.sh"
    local title="✓  Tahow Shell instalado com sucesso"
    [[ "$MODE" == "update" ]] && title="✓  Tahow Shell atualizado com sucesso"

    echo -e ""
    echo -e "  ${DIM}────────────────────────────────────────────────────${RESET}"
    echo -e "  ${SUCCESS}${BOLD}${title}${RESET}"
    echo -e ""

    if [[ "$SCALE_WARNING" == true ]]; then
        echo -e "  ${WARNING}${BOLD}Aviso de Escala do Monitor:${RESET}"
        echo -e "    Escala fracionária detectada. O provider nativo ${BOLD}live-glass${RESET} requer"
        echo -e "    ${BOLD}scale = 1${RESET} em ${DIM}~/.config/hypr/config/monitors.lua${RESET} para refração ao vivo."
        echo -e ""
    fi

    if [[ ${#MISSING_MANUAL_DEPS[@]} -gt 0 ]]; then
        echo -e "  ${WARNING}${BOLD}Ação manual necessária (Fallback):${RESET}"
        echo -e "    Instale os seguintes pacotes na sua distribuição:"
        echo -e "    ${BOLD}${MISSING_MANUAL_DEPS[*]}${RESET}"
        echo -e ""
    fi

    echo -e "  ${BOLD}Comandos úteis:${RESET}"
    if [[ "$MODE" != "update" ]]; then
        echo -e "    ${DIM}1.${RESET} Ativar agora:     ${ACCENT}${activate_cmd}${RESET}"
        echo -e "    ${DIM}2.${RESET} Atualizar depois: ${GRAY}${script_ref} --update${RESET}"
        echo -e "    ${DIM}3.${RESET} Reverter tudo:    ${GRAY}${script_ref} --uninstall${RESET}"
        echo -e "    ${DIM}4.${RESET} Log técnico:      ${GRAY}${display_log}${RESET}"
    else
        echo -e "    ${DIM}1.${RESET} Reverter tudo:    ${GRAY}${script_ref} --uninstall${RESET}"
        echo -e "    ${DIM}2.${RESET} Log técnico:      ${GRAY}${display_log}${RESET}"
    fi
    echo -e ""
}

# ------------------------------------------------------------------------------
# Execução
# ------------------------------------------------------------------------------
print_banner
require_privileges
init_environment
install_dependencies
for required in qs rsync; do
    if ! command -v "$required" >/dev/null; then
        warn_item "Dependência obrigatória ausente: $required"
        exit 1
    fi
done
sync_repository
build_and_deploy_assets
configure_hyprland
print_summary
