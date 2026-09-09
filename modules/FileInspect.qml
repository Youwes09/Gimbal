import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string path: ""
    property string kind: ""
    property string mime: ""
    property string text: ""
    property var rows: []

    function _fmtBytes(n) {
        if (!n) return "0 B"
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0, v = n
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (i === 0 ? v : v.toFixed(v < 10 ? 1 : 0)) + " " + u[i]
    }

    function clear() {
        root.path = ""; root.kind = ""; root.mime = ""; root.text = ""; root.rows = []
    }

    function load(p) {
        if (!p || p.length === 0) { clear(); return }
        root.path = p
        root.kind = ""; root.mime = ""; root.text = ""; root.rows = []
        _probe.command = ["sh", "-c", _script, "_", p]
        _probe.running = true
    }

    readonly property string _script:
        'p="$1"; [ -e "$p" ] || { echo "K other"; exit 0; }; '
      + 'if [ -d "$p" ]; then echo "K dir"; '
      +   'echo "I Items|$(ls -1A "$p" 2>/dev/null | wc -l | tr -d " ")"; exit 0; fi; '
      + 'echo "SZ $(stat -c %s "$p" 2>/dev/null)"; '
      + 'echo "MT $(stat -c %y "$p" 2>/dev/null | cut -d. -f1)"; '
      + 'm=""; command -v file >/dev/null 2>&1 && m=$(file -Lb --mime-type "$p" 2>/dev/null); '
      + 'echo "MIME $m"; '
      + 'command -v file >/dev/null 2>&1 && echo "DESC $(file -Lb "$p" 2>/dev/null)"; '
      + 'e=$(printf "%s" "${p##*.}" | tr "A-Z" "a-z"); '
      + 'case "$e" in '
      +   'png|jpg|jpeg|webp|gif|bmp|avif|ico) echo "K image"; exit 0;; '
      +   'svg) echo "K image"; exit 0;; '
      +   'mp4|webm|mkv|mov|avi|m4v|flv) echo "K video"; exit 0;; '
      +   'mp3|flac|wav|ogg|opus|m4a|aac) echo "K audio"; exit 0;; '
      +   'pdf) echo "K pdf"; exit 0;; '
      +   'zip|tar|gz|xz|zst|7z|rar|bz2|lz4) echo "K archive"; exit 0;; '
      + 'esac; '
      + 'case "$m" in '
      +   'image/*) echo "K image"; exit 0;; '
      +   'video/*) echo "K video"; exit 0;; '
      +   'audio/*) echo "K audio"; exit 0;; '
      +   'application/pdf) echo "K pdf"; exit 0;; '
      +   'application/zip|application/x-tar|application/gzip|application/x-7z*) echo "K archive"; exit 0;; '
      +   'text/*|application/json|application/xml|application/javascript|application/x-shellscript) '
      +     'echo "K text"; echo "T-BEGIN"; head -c 200000 "$p"; exit 0;; '
      + 'esac; '
      + 'sig=$(head -c 4 "$p" | od -An -tx1 2>/dev/null | tr -d " \\n"); '
      + 'case "$sig" in '
      +   '7f454c46*) echo "K binary"; echo "I Format|ELF binary"; exit 0;; '
      +   '4d5a*) echo "K binary"; echo "I Format|PE executable"; exit 0;; '
      +   'cafebabe*|feedface*|feedfacf*|cffaedfe*) echo "K binary"; echo "I Format|Mach-O binary"; exit 0;; '
      +   '25504446*) echo "K pdf"; exit 0;; '
      +   '504b0304*) echo "K archive"; exit 0;; '
      + 'esac; '
      + 'np=$(head -c 8000 "$p" | LC_ALL=C tr -d "[:print:]\\t\\n\\r" | wc -c | tr -d " "); '
      + 'if [ "${np:-1}" -eq 0 ]; then echo "K text"; echo "T-BEGIN"; head -c 200000 "$p"; '
      + 'else echo "K binary"; fi'

    property Process _probe: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (this.text || "").split("\n")
                let k = "", sz = 0, mt = "", mime = "", desc = "", body = null
                const extra = []
                for (let i = 0; i < lines.length; i++) {
                    const l = lines[i]
                    if (l.indexOf("T-BEGIN") === 0) { body = lines.slice(i + 1).join("\n"); break }
                    if (l.indexOf("K ") === 0)      k = l.slice(2).trim()
                    else if (l.indexOf("SZ ") === 0)   sz = parseInt(l.slice(3)) || 0
                    else if (l.indexOf("MT ") === 0)   mt = l.slice(3).trim()
                    else if (l.indexOf("MIME ") === 0) mime = l.slice(5).trim()
                    else if (l.indexOf("DESC ") === 0) desc = l.slice(5).trim()
                    else if (l.indexOf("I ") === 0) {
                        const parts = l.slice(2).split("|")
                        extra.push([parts[0], parts[1] || ""])
                    }
                }
                root.kind = k || "other"
                root.mime = mime
                root.text = body || ""

                const rows = []
                if (desc && root.kind === "binary") rows.push(["Format", desc])
                else if (mime) rows.push(["Type", mime])
                if (sz) rows.push(["Size", root._fmtBytes(sz)])
                if (mt) rows.push(["Modified", mt])
                for (const r of extra) rows.push(r)
                if (root.kind === "text") {
                    const t = root.text
                    rows.push(["Lines", "" + t.split("\n").length])
                    rows.push(["Characters", "" + t.length])
                }
                root.rows = rows
            }
        }
    }
}
