pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string _home: Quickshell.env("HOME")
    readonly property var roots: Config.fileRoots

    property var list: []

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function _short(p) {
        return p.indexOf(root._home) === 0 ? "~" + p.slice(root._home.length) : p
    }
    function _parent(p) { return p.replace(/\/[^/]*$/, "") || "/" }

    function rescan() {
        _scan.running = false
        Qt.callLater(() => _scan.running = true)
    }

    function openEditor(path) {
        Quickshell.execDetached(["sh", "-c", Config.editor + ' "$1"', "_", path])
    }
    function openManager(path) {
        Quickshell.execDetached(["sh", "-c",
            _q(Config.fileManager) + ' "$1" 2>/dev/null || xdg-open "$1"', "_", path])
    }
    function openTerminal(path, isDir) {
        const dir = isDir ? path : root._parent(path)
        Quickshell.execDetached(["sh", "-c",
            _q(Config.terminal) + ' -D "$1" 2>/dev/null || '
            + _q(Config.terminal) + ' --working-directory="$1" 2>/dev/null || '
            + '(cd "$1" && exec ' + _q(Config.terminal) + ')', "_", dir])
    }

    function openSmart(path) {
        Quickshell.execDetached(["sh", "-c",
            'd="$1"; for m in .git flake.nix Cargo.toml package.json pyproject.toml '
            + 'Makefile go.mod deno.json .project; do '
            + '[ -e "$d/$m" ] && exec ' + _q(Config.editor) + ' "$d"; done; '
            + _q(Config.fileManager) + ' "$d" 2>/dev/null || xdg-open "$d"',
            "_", path])
    }

    property Process _scan: Process {
        command: ["sh", "-c",
            'H="$HOME"; '
            + 'find "$H" -maxdepth 1 -mindepth 1 '
            +   '\\( -type d -printf "d %p\\n" -o -type f -printf "f %p\\n" \\) 2>/dev/null; '
            + 'for r in "$@"; do [ -d "$r" ] || continue; '
            +   'find "$r" -maxdepth 4 -mindepth 1 '
            +   '-not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.cache/*" '
            +   '-not -path "*/target/*" -not -path "*/.venv/*" -not -path "*/__pycache__/*" '
            +   '\\( -type d -printf "d %p\\n" -o -type f -printf "f %p\\n" \\) 2>/dev/null; '
            + 'done | head -n 15000',
            "_"].concat(root.roots)
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const seen = ({})
                const lines = (this.text || "").split("\n")
                for (const ln of lines) {
                    if (ln.length < 3) continue
                    const isDir = ln[0] === "d"
                    const p = ln.slice(2)
                    if (seen[p]) continue
                    seen[p] = true
                    const slash = p.lastIndexOf("/")
                    out.push({
                        path:  p,
                        name:  slash >= 0 ? p.slice(slash + 1) : p,
                        dir:   root._short(slash >= 0 ? p.slice(0, slash) : p),
                        isDir: isDir
                    })
                }
                root.list = out
            }
        }
    }
}
