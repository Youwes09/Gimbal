pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// Audio spectrum from cava. Runs only while music plays and something showing it is up.
QtObject {
    id: root

    readonly property int count: 24
    property var levels: []   // 0..1 per band, low to high; empty while stopped

    readonly property bool live: Config.visualizer && Status.playing
        && (Sh.deckShown || Sh.barEdge !== "")

    // `n` bands from the full set, each the loudest of its slice.
    function bands(n) {
        const l = root.levels, out = []
        for (let i = 0; i < n; i++) {
            let m = 0
            for (let j = Math.floor(i * l.length / n); j < Math.floor((i + 1) * l.length / n); j++) m = Math.max(m, l[j])
            out.push(m)
        }
        return out
    }

    readonly property string _conf: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/gimbal-cava.conf"

    property Process _cava: Process {
        running: root.live
        command: ["sh", "-c",
            'command -v cava >/dev/null || exit 0; '
            + 'printf "[general]\\nbars=%s\\nframerate=30\\n[smoothing]\\nnoise_reduction=70\\n'
            + '[output]\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=1000\\nbar_delimiter=59\\n" '
            + '"$1" > "$2" && exec cava -p "$2"',
            "_", String(root.count), root._conf]
        onRunningChanged: if (!running) root.levels = []
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.split(";"), v = []
                for (let i = 0; i < root.count && i < p.length; i++) v.push((parseInt(p[i]) || 0) / 1000)
                if (v.length === root.count) root.levels = v
            }
        }
    }
}
