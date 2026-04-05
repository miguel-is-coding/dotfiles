#!/usr/bin/env bash
set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────────
# 1. Xcode Command Line Tools
# ─────────────────────────────────────────────
info "Verificando Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
  info "Instalando Xcode Command Line Tools..."
  xcode-select --install
  # Esperar a que el usuario complete la instalación GUI
  echo "Pulsa ENTER cuando la instalación de Xcode CLT haya finalizado."
  read -r
else
  info "Xcode CLT ya instalado: $(xcode-select -p)"
fi

# ─────────────────────────────────────────────
# 2. Homebrew
# ─────────────────────────────────────────────
info "Verificando Homebrew..."
if ! command -v brew &>/dev/null; then
  info "Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Configurar PATH para Apple Silicon
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  info "Homebrew ya instalado: $(brew --version | head -1)"
fi

# Asegurar que brew está en el PATH en esta sesión (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ─────────────────────────────────────────────
# 3. Brew Bundle
# ─────────────────────────────────────────────
info "Instalando paquetes desde Brewfile..."
brew bundle --file="$DOTFILES_DIR/Brewfile" || warning "Algunos paquetes fallaron; revisa el output anterior."

# ─────────────────────────────────────────────
# 4. Aceptar licencia de Xcode (requiere que Xcode esté instalado via mas)
# ─────────────────────────────────────────────
info "Aceptando licencia de Xcode..."
if sudo xcodebuild -license accept 2>/dev/null; then
  info "Licencia de Xcode aceptada."
else
  warning "No se pudo aceptar la licencia de Xcode automáticamente. Puede que Xcode aún no esté instalado vía mas."
fi

# ─────────────────────────────────────────────
# 5. Oh My Zsh
# ─────────────────────────────────────────────
info "Verificando Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  info "Instalando Oh My Zsh (modo no interactivo)..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  info "Oh My Zsh ya instalado."
fi

# ─────────────────────────────────────────────
# 6. Symlinks dotfiles
# ─────────────────────────────────────────────
info "Creando symlinks de dotfiles..."

symlink() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    info "Symlink ya existe: $dst → $(readlink "$dst")"
  elif [ -f "$dst" ]; then
    warning "Archivo existente en $dst — haciendo backup como $dst.bak"
    mv "$dst" "$dst.bak"
    ln -s "$src" "$dst"
    info "Symlink creado: $dst → $src"
  else
    ln -s "$src" "$dst"
    info "Symlink creado: $dst → $src"
  fi
}

symlink "$DOTFILES_DIR/.zshrc"            "$HOME/.zshrc"
symlink "$DOTFILES_DIR/.gitconfig"        "$HOME/.gitconfig"
symlink "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"

# Registrar gitignore_global en git config si no está registrado
if ! git config --global core.excludesfile &>/dev/null; then
  git config --global core.excludesfile "$HOME/.gitignore_global"
  info "gitignore_global registrado en git config."
fi

# ─────────────────────────────────────────────
# 7. Symlinks VS Code
# ─────────────────────────────────────────────
info "Creando symlinks de VS Code..."
VSCODE_PREFS="$HOME/Library/Application Support/Code/User"

if [ -d "$VSCODE_PREFS" ]; then
  symlink "$DOTFILES_DIR/vscode_settings.json"    "$VSCODE_PREFS/settings.json"
  symlink "$DOTFILES_DIR/vscode_keybindings.json" "$VSCODE_PREFS/keybindings.json"
else
  warning "VS Code no instalado aún o preferences no encontradas en: $VSCODE_PREFS"
  warning "Ejecuta VS Code una vez y luego vuelve a lanzar este script para crear los symlinks."
fi

# ─────────────────────────────────────────────
# 8. Claude Code
# ─────────────────────────────────────────────
info "Instalando Claude Code..."
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
  info "Claude Code instalado."
else
  info "Claude Code ya instalado: $(claude --version 2>/dev/null || echo 'versión desconocida')"
fi

# ─────────────────────────────────────────────
# 9. SDKMan (Java, Kotlin, Gradle)
# ─────────────────────────────────────────────
info "Verificando SDKMan..."
if [ ! -d "$HOME/.sdkman" ]; then
  info "Instalando SDKMan..."
  curl -s "https://get.sdkman.io" | bash
  export SDKMAN_DIR="$HOME/.sdkman"
  # shellcheck disable=SC1091
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  info "SDKMan instalado. Instala Java/Kotlin con: sdk install java / sdk install kotlin"
else
  info "SDKMan ya instalado."
  export SDKMAN_DIR="$HOME/.sdkman"
  # shellcheck disable=SC1091
  source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# ─────────────────────────────────────────────
# 10. Flutter (via FVM)
# ─────────────────────────────────────────────
info "Verificando FVM (Flutter Version Manager)..."
if command -v fvm &>/dev/null; then
  info "FVM disponible: $(fvm --version)"
  info "Ejecutando fvm flutter doctor..."
  fvm flutter doctor || warning "flutter doctor reportó problemas. Revisa manualmente."
else
  warning "FVM no encontrado en PATH. Puede necesitar reiniciar el shell o instalar Flutter manualmente."
fi

# ─────────────────────────────────────────────
# 11. Pasos manuales restantes
# ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}  PASOS MANUALES RESTANTES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Flutter vía FVM (instalar versión estable):"
echo "     fvm install stable && fvm global stable"
echo "     Luego verificar: fvm flutter doctor"
echo ""
echo "  2. Java/Kotlin/Gradle vía SDKMan:"
echo "     sdk install java && sdk install kotlin && sdk install gradle"
echo ""
echo "  3. JetBrains Toolbox: Abrir y instalar IntelliJ IDEA,"
echo "     WebStorm, Android Studio, CLion y Rider."
echo ""
echo "  4. Unity Hub: Abrir, iniciar sesión y activar licencia."
echo "     Instalar Unity 6 (LTS) con módulo WebGL."
echo ""
echo "  5. Claves SSH:"
echo "     - Opción A: Copiar desde M1:  scp ~/.ssh/id_ed25519* <nuevo-mac>:~/.ssh/"
echo "     - Opción B: Generar nuevas:   ssh-keygen -t ed25519 -C 'tu@email.com'"
echo "       Luego añadir la clave pública a GitLab."
echo ""
echo "  6. OrbStack: Abrir y completar el setup inicial."
echo ""
echo "  7. FortiClient (si es EMS enterprise):"
echo "     Introducir la dirección del servidor EMS manualmente."
echo ""
echo "  8. 1Password: Iniciar sesión para restaurar todas las credenciales."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}  Bootstrap completado.${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
