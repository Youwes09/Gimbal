pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// Profiles, contribution calendars, repos and activity for the accounts in Config.github.
// Cached on disk; refetched when the GitHub page opens and the copy is over ten minutes old.
QtObject {
    id: root

    readonly property var accounts: Config.github
    property var data: ({})   // user → { profile, days, total, repos, events, at }
    property string loading: ""

    readonly property string _dir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/gimbal"
    readonly property string _path: root._dir + "/github.json"

    function stale(user) { const d = root.data[user]; return !d || Date.now() - d.at > 10 * 60000 }
    function refresh(force) {
        const want = root.accounts.map(a => a.user)
            .filter(u => (force || root.stale(u)) && root._queue.indexOf(u) < 0 && root.loading !== u)
        root._queue = root._queue.concat(want)
        root._next()
    }

    property var _queue: []   // reassigned, never mutated: a var array hands out copies
    function _next() {
        if (_fetch.running || root.loading || root._queue.length === 0) return
        const u = root._queue[0]
        root._queue = root._queue.slice(1)
        const a = root.accounts.find(x => x.user === u)
        if (!a) { root._next(); return }
        root.loading = a.user
        _fetch.user = a.user
        _fetch.command = ["sh", "-c", root._script, "_", a.user, a.token, a.tokenFile, root._graphql(a.user), root._cells]
        _fetch.running = true
    }

    // One section per source, each after an @@ marker. With a token, private repos, activity and the
    // full calendar come from the authenticated API (public data if it is refused); without, the
    // public profile page.
    readonly property string _script:
          'u=$1; t=$2; [ -z "$t" ] && [ -n "$3" ] && [ -r "$3" ] && t=$(tr -d "[:space:]" < "$3")\n'
        + 'g() { if [ -n "$t" ]; then curl -sfL --max-time 15 -H "Authorization: Bearer $t" "$@"; else curl -sfL --max-time 15 "$@"; fi; }\n'
        + 'echo @@profile; if [ -n "$t" ]; then g https://api.github.com/user || { t=; g "https://api.github.com/users/$u"; }; else g "https://api.github.com/users/$u"; fi; echo\n'
        + 'echo @@repos\n'
        + 'if [ -n "$t" ]; then g "https://api.github.com/user/repos?per_page=100&sort=pushed&affiliation=owner,collaborator,organization_member"\n'
        + 'else g "https://api.github.com/users/$u/repos?per_page=100&sort=pushed"; fi; echo\n'
        + 'echo @@events; g "https://api.github.com/users/$u/events?per_page=60"; echo\n'
        + 'if [ -n "$t" ]; then echo @@graphql; g -X POST -d "$4" https://api.github.com/graphql\n'
        + 'else echo @@calendar; curl -sfL --max-time 15 "https://github.com/users/$u/contributions" | tr -d "\\n" | grep -oE "$5"; fi\n'
    function _graphql(user) {
        return JSON.stringify({ query: "query($u:String!){user(login:$u){contributionsCollection{contributionCalendar"
            + "{totalContributions weeks{contributionDays{date contributionCount contributionLevel}}}}}}",
            variables: { u: user } })
    }
    readonly property string _cells: 'data-date="[0-9-]+" id="contribution-day-component-[0-9-]+" data-level="[0-4]"'
        + '|for="contribution-day-component-[0-9-]+"[^>]*>[^<]*|contribution-activity-description"[^>]*>[^<]*'

    // The next fetch starts once this one has both exited and been read, whichever comes last.
    property Process _fetch: Process {
        property string user: ""
        onRunningChanged: if (!running) Qt.callLater(root._next)
        stdout: StdioCollector {
            onStreamFinished: { root._ingest(root._fetch.user, this.text); root.loading = ""; Qt.callLater(root._next) }
        }
    }

    function _ingest(user, text) {
        const parts = {}
        for (const chunk of text.split(/^@@/m)) {
            const nl = chunk.indexOf("\n")
            if (nl > 0) parts[chunk.slice(0, nl).trim()] = chunk.slice(nl + 1)
        }
        const json = s => { try { return JSON.parse(s) } catch (e) { return null } }
        const profile = json(parts.profile || "")
        if (!profile || !profile.login) return   // offline or rate limited: keep what's cached

        // With a token that is every repo the account works in, its orgs' too; without, the ones it owns.
        const all = (json(parts.repos || "") || []).filter(r => r && r.owner)
        const own = all.filter(r => r.owner.login.toLowerCase() === user.toLowerCase())
        const langs = {}
        for (const r of all) if (r.language && !r.fork) langs[r.language] = (langs[r.language] || 0) + 1

        const cal = parts.graphql !== undefined ? root._fromGraphql(json(parts.graphql)) : root._fromPage(parts.calendar || "")
        const prev = root.data[user]
        const d = Object.assign({}, root.data)
        d[user] = {
            at: Date.now(),
            authed: parts.graphql !== undefined,
            profile: { login: profile.login, name: profile.name || "", avatar: profile.avatar_url || "",
                       url: profile.html_url, followers: profile.followers || 0, following: profile.following || 0,
                       repos: (profile.public_repos || 0) + (profile.total_private_repos || 0) },
            stars: own.filter(r => !r.fork).reduce((s, r) => s + (r.stargazers_count || 0), 0),
            languages: Object.keys(langs).sort((a, b) => langs[b] - langs[a]).slice(0, 3),
            repos: all.slice(0, 8).map(r => ({
                name: own.indexOf(r) >= 0 ? r.name : r.full_name, desc: r.description || "",
                lang: r.language || "", stars: r.stargazers_count || 0,
                fork: !!r.fork, private: !!r.private, url: r.html_url, pushed: Date.parse(r.pushed_at) || 0 })),
            events: root._events(json(parts.events || "") || []),
            days: cal.days.length ? cal.days : (prev ? prev.days : []),
            total: cal.days.length ? cal.total : (prev ? prev.total : 0)
        }
        root.data = d
        root._save()
    }

    function _fromGraphql(j) {
        const c = j && j.data && j.data.user && j.data.user.contributionsCollection.contributionCalendar
        if (!c) return { days: [], total: 0 }
        const lv = { NONE: 0, FIRST_QUARTILE: 1, SECOND_QUARTILE: 2, THIRD_QUARTILE: 3, FOURTH_QUARTILE: 4 }
        const days = []
        for (const w of c.weeks) for (const x of w.contributionDays)
            days.push({ date: x.date, count: x.contributionCount, level: lv[x.contributionLevel] || 0 })
        return { days: days, total: c.totalContributions }
    }
    function _fromPage(s) {
        const cells = {}, counts = {}
        let total = -1
        for (const ln of s.split("\n")) {
            let m = /data-date="([\d-]+)" id="contribution-day-component-([\d-]+)" data-level="(\d)"/.exec(ln)
            if (m) { cells[m[2]] = { date: m[1], level: +m[3], count: 0 }; continue }
            m = /for="contribution-day-component-([\d-]+)"[^>]*>\s*(No|[\d,]+) contribution/.exec(ln)
            if (m) { counts[m[1]] = m[2] === "No" ? 0 : parseInt(m[2].replace(/,/g, "")); continue }
            m = /contribution-activity-description"[^>]*>\s*([\d,]+)/.exec(ln)
            if (m) total = parseInt(m[1].replace(/,/g, ""))
        }
        const days = Object.keys(cells).map(id => Object.assign(cells[id], { count: counts[id] || 0 }))
            .sort((a, b) => a.date < b.date ? -1 : 1)
        return { days: days, total: total >= 0 ? total : days.reduce((s, x) => s + x.count, 0) }
    }

    // Recent activity, one line each. Back-to-back pushes to the same branch count as one.
    function _events(list) {
        const out = []
        for (const e of list) {
            const repo = e.repo ? e.repo.name : "", short = repo.split("/").pop(), p = e.payload || {}
            const at = Date.parse(e.created_at) || 0, web = "https://github.com/" + repo
            let x = null
            if (e.type === "PushEvent") {
                const br = (p.ref || "").replace("refs/heads/", ""), last = out[out.length - 1]
                if (last && last.kind === "push" && last.repo === repo && last.branch === br) { last.n++; continue }
                x = { kind: "push", branch: br, n: 1, text: "Pushed to " + short, sub: br, url: p.head ? web + "/commit/" + p.head : web }
            } else if (e.type === "PullRequestEvent" && p.pull_request) {
                const verb = p.action === "closed" ? (p.pull_request.merged ? "Merged" : "Closed") : p.action === "opened" ? "Opened" : ""
                if (verb) x = { kind: "pr", text: verb + " #" + p.pull_request.number + " in " + short, sub: p.pull_request.title || "", url: p.pull_request.html_url }
            } else if (e.type === "IssuesEvent" && p.issue && (p.action === "opened" || p.action === "closed")) {
                x = { kind: "issue", text: (p.action === "opened" ? "Opened" : "Closed") + " issue #" + p.issue.number + " in " + short, sub: p.issue.title || "", url: p.issue.html_url }
            } else if (e.type === "IssueCommentEvent" && p.issue) {
                x = { kind: "comment", text: "Commented on #" + p.issue.number + " in " + short, sub: p.issue.title || "", url: p.comment ? p.comment.html_url : p.issue.html_url }
            } else if (e.type === "CreateEvent") {
                x = p.ref_type === "repository" ? { kind: "create", text: "Created " + short, sub: "", url: web }
                  : p.ref_type === "tag" ? { kind: "create", text: "Tagged " + p.ref + " in " + short, sub: "", url: web + "/releases/tag/" + p.ref } : null
            } else if (e.type === "ReleaseEvent" && p.release) {
                x = { kind: "release", text: "Released " + (p.release.tag_name || "") + " in " + short, sub: p.release.name || "", url: p.release.html_url }
            } else if (e.type === "WatchEvent") {
                x = { kind: "star", text: "Starred " + repo, sub: "", url: web }
            } else if (e.type === "ForkEvent") {
                x = { kind: "fork", text: "Forked " + repo, sub: "", url: p.forkee ? p.forkee.html_url : web }
            } else if (e.type === "PublicEvent") {
                x = { kind: "create", text: "Made " + short + " public", sub: "", url: web }
            }
            if (x) out.push(Object.assign(x, { repo: repo, at: at }))
            if (out.length >= 12) break
        }
        out.sort((a, b) => b.at - a.at)
        for (const x of out) if (x.kind === "push" && x.n > 1) x.text = "Pushed " + x.n + " times to " + x.repo.split("/").pop()
        return out
    }

    // Days in a row with a contribution, counting back from today (or yesterday, if today has none yet).
    function streak(days) {
        let i = days.length - 1, n = 0
        if (i >= 0 && days[i].count === 0) i--
        for (; i >= 0 && days[i].count > 0; i--) n++
        return n
    }

    function _save() { _file.setText(JSON.stringify(root.data)) }
    property FileView _file: FileView {
        path: root._path
        printErrors: false
        onLoaded: { try { root.data = JSON.parse(text() || "{}") } catch (e) { root.data = ({}) } }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root._dir])
}
