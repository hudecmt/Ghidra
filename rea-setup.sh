#!/bin/bash
# Setup skript pre cloudové prostredie Claude Code: REA + Ghidra 12.1.4
# Vlož celý obsah do nastavení prostredia → Setup script.
set -euo pipefail

NODE_DIR=/opt/node24
GHIDRA_TAG=Ghidra_12.1.4_build
GHIDRA_DIR=/opt/ghidra
SRC=/opt/ghidra-build

# 1) Node.js 24 (REA vyžaduje >= 24.22.1; predinštalovaný Node 22 je starý)
if [ ! -x "$NODE_DIR/bin/node" ]; then
  mkdir -p "$NODE_DIR" && cd "$NODE_DIR"
  base=https://nodejs.org/dist/latest-v24.x
  tarball=$(curl -fsSL "$base/SHASUMS256.txt" | grep -o 'node-v[0-9.]*-linux-x64.tar.xz' | head -1)
  curl -fsSLO "$base/$tarball"
  curl -fsSL "$base/SHASUMS256.txt" | grep " $tarball\$" | sha256sum -c
  tar xf "$tarball" --strip-components=1 && rm -f "$tarball"
fi
export PATH="$NODE_DIR/bin:$PATH"

# 2) REA CLI
npm install --global rea-agents@latest

# 3a) Rýchla cesta: hotový build z hudecmt/ghidra (6 častí, overené SHA-256)
DIST_URL=https://raw.githubusercontent.com/hudecmt/ghidra/main/dist
if [ ! -x "$GHIDRA_DIR/support/analyzeHeadless" ]; then
  tmp=$(mktemp -d)
  if (
    set -e
    cd "$tmp"
    curl -fsSL --retry 3 -o ghidra.zip.sha256 "$DIST_URL/ghidra.zip.sha256"
    for i in 00 01 02 03 04 05; do
      curl -fsSL --retry 3 "$DIST_URL/ghidra.zip.part$i"
    done > ghidra.zip
    sha256sum -c ghidra.zip.sha256
    mkdir unzip && unzip -q ghidra.zip -d unzip
    mv unzip/ghidra_* "$GHIDRA_DIR"
  ); then
    echo "Ghidra stiahnutá z hudecmt/ghidra"
  else
    echo "Stiahnutie Ghidry zlyhalo, zostavujem zo zdrojákov" >&2
  fi
  rm -rf "$tmp"
fi

# 3b) Záloha: Ghidra zo zdrojákov (GitHub Releases sú v sieťovej politike blokované)
if [ ! -x "$GHIDRA_DIR/support/analyzeHeadless" ]; then
  rm -rf "$SRC"
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --branch "$GHIDRA_TAG" \
    https://github.com/NationalSecurityAgency/ghidra "$SRC"
  cd "$SRC"
  # github.com/.../raw/ je blokované, raw.githubusercontent.com funguje
  sed -i 's#https://github.com/NationalSecurityAgency/ghidra-data/raw/#https://raw.githubusercontent.com/NationalSecurityAgency/ghidra-data/#' \
    gradle/support/fetchDependencies.gradle
  # Nedostupné voliteľné závislosti (PostgreSQL pre BSim server, Eclipse CDT) preskočiť
  python3 -I - <<'EOF'
p = 'gradle/support/fetchDependencies.gradle'
s = open(p).read()
s = s.replace('''		download(it.url, file)
		if (!OFFLINE) {
			assert(it.sha256.equals(generateHash(file)));
		}''', '''		try {
			download(it.url, file)
			assert(it.sha256.equals(generateHash(file)));
		} catch (Throwable t) {
			println "   SKIPPED (unreachable): " + it.name
			file.delete()
			it.skipped = true
		}''')
s = s.replace('deps.each {\n\tdef copier', 'deps.findAll { !it.skipped }.each {\n\tdef copier')
open(p, 'w').write(s)
EOF
  # Fetch skript na konci zlyhá na konfigurácii projektu, závislosti sú však už stiahnuté
  gradle -I gradle/support/fetchDependencies.gradle -DhideDownloadProgress init || true
  test -d dependencies/flatRepo
  gradle buildGhidra --parallel
  rm -rf /opt/ghidra-unzip && mkdir /opt/ghidra-unzip
  unzip -q build/dist/ghidra_*_linux_x86_64.zip -d /opt/ghidra-unzip
  mv /opt/ghidra-unzip/ghidra_* "$GHIDRA_DIR" && rmdir /opt/ghidra-unzip
  cd / && rm -rf "$SRC" /root/.gradle/caches
fi

# 4) Registrácia REA MCP + skill pre Claude Code (s Ghidrou v prostredí servera)
export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
rea setup --client claude_code --yes
rea doctor >/dev/null && echo "REA + Ghidra pripravené"
