#!/usr/bin/env bash
#
# install-mpxj.sh
#
# Installs build dependencies (Homebrew, git, a JDK, Maven) and builds MPXJ
# from the latest source on GitHub (joniles/mpxj, master branch).
#
# Target: macOS. Requires an interactive shell the first time if Homebrew
# itself isn't installed yet (the Homebrew installer will prompt for your
# sudo password).
#
# Usage:
#   ./install-mpxj.sh [install_dir]
#
# install_dir defaults to ~/dev/mpxj. Re-running the script pulls the latest
# master and rebuilds, rather than re-cloning.

set -euo pipefail

INSTALL_DIR="${1:-$HOME/dev/mpxj}"
REPO_URL="https://github.com/joniles/mpxj.git"

log()  { printf '\n[install-mpxj] %s\n' "$1"; }
die()  { printf '\n[install-mpxj] ERROR: %s\n' "$1" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This script targets macOS. On Linux, swap the brew steps for your package manager (git, a JDK 11+, maven)."
fi

# ---------------------------------------------------------------------------
# 1. Homebrew
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Homebrew not found — installing (will prompt for your password)."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -d /opt/homebrew/bin ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -d /usr/local/bin ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  log "Homebrew already installed."
fi

command -v brew >/dev/null 2>&1 || die "Homebrew install appears to have failed — brew not on PATH."

# ---------------------------------------------------------------------------
# 2. git, JDK, Maven
# ---------------------------------------------------------------------------
log "Updating Homebrew (this can take a minute)."
brew update

for pkg in git openjdk maven; do
  if brew list --versions "$pkg" >/dev/null 2>&1; then
    log "$pkg already installed via Homebrew."
  else
    log "Installing $pkg via Homebrew."
    brew install "$pkg"
  fi
done

# openjdk from Homebrew is keg-only (not symlinked into PATH by default).
# Resolve JAVA_HOME and prepend it to PATH for the rest of this script.
OPENJDK_PREFIX="$(brew --prefix openjdk)"
export JAVA_HOME="$OPENJDK_PREFIX/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

command -v java >/dev/null 2>&1 || die "java not found on PATH after setting JAVA_HOME=$JAVA_HOME"
command -v mvn  >/dev/null 2>&1 || die "mvn not found on PATH."

log "Using: $(java -version 2>&1 | head -n1)"
log "Using: $(mvn -version | head -n1)"

# ---------------------------------------------------------------------------
# 3. Clone or update MPXJ
# ---------------------------------------------------------------------------
if [[ -d "$INSTALL_DIR/.git" ]]; then
  log "Existing checkout found at $INSTALL_DIR — fetching latest master."
  git -C "$INSTALL_DIR" fetch origin
  git -C "$INSTALL_DIR" checkout master
  git -C "$INSTALL_DIR" pull origin master
else
  log "Cloning $REPO_URL into $INSTALL_DIR."
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ---------------------------------------------------------------------------
# 4. Build
# ---------------------------------------------------------------------------
log "Building MPXJ (tests, javadoc, and source jar skipped for speed)."
(
  cd "$INSTALL_DIR"
  mvn -q -DskipTests=true -Dmaven.javadoc.skip=true -Dsource.skip=true package
)

BUILD_JAR="$(find "$INSTALL_DIR" -maxdepth 3 -type f -name 'mpxj-*.jar' ! -name '*sources*' ! -name '*javadoc*' | head -n1)"
LIB_DIR="$(find "$INSTALL_DIR" -maxdepth 2 -type d -name 'lib' | head -n1)"

[[ -n "$BUILD_JAR" ]] || die "Build finished but no mpxj-*.jar was found under $INSTALL_DIR — check the Maven output above."

log "Build complete."
echo "  JAR:  $BUILD_JAR"
[[ -n "$LIB_DIR" ]] && echo "  Deps: $LIB_DIR"

# ---------------------------------------------------------------------------
# 5. Convenience wrapper for the bundled CLI converter
# ---------------------------------------------------------------------------
WRAPPER="$INSTALL_DIR/mpxj-convert.sh"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
# Convert a project file to another format, e.g.:
#   ./mpxj-convert.sh input.mpp output.xml
set -euo pipefail
export JAVA_HOME="$JAVA_HOME"
exec "\$JAVA_HOME/bin/java" -cp "$BUILD_JAR:$LIB_DIR/*" org.mpxj.sample.MpxjConvert "\$@"
EOF
chmod +x "$WRAPPER"

log "Wrapper script written to $WRAPPER"
echo "  Example: $WRAPPER my-plan.mpp my-plan.xml"
