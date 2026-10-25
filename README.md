# Ghidra 12.1.4 – linux x86_64 build

Ghidra 12.1.4 (tag `Ghidra_12.1.4_build`) zostavená zo zdrojákov
[NationalSecurityAgency/ghidra](https://github.com/NationalSecurityAgency/ghidra)
pre cloudové prostredie Claude Code (REA). Zip je rozdelený na časti pod 100 MB.

Bez BSim PostgreSQL servera a pluginu GhidraDev pre Eclipse (ich závislosti neboli dostupné).

Zloženie: `cat dist/ghidra.zip.part* > ghidra.zip && sha256sum -c dist/ghidra.zip.sha256`

Licencia: Apache 2.0 (pozri `LICENSE`), časti v `GPL/` pod GPL.
