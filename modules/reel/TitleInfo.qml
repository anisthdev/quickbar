import QtQuick
import "../.."
import "Languages.js" as Languages

// What a title's page shows, worked out once for both of its looks (the
// menu's TitlePage, the window's TitleScreen): its seasons, what has aired
// and what's here, the season's episodes, its scores, whether a show is on
// the air, and its facts in words.
QtObject {
    id: root

    // The title, from Reel's model (with progress, marks and languages)
    property var item: null
    // The season on show
    property int season: 0

    readonly property bool series: item?.kind === "series"
    readonly property var seasons: series ? [...new Set(item.episodes.map(e => e.season))] : []
    // What has aired, season by season, from TMDB (null when reel doesn't
    // know): a season's announced episodes count once they're out
    readonly property var aired: {
        const t = item?.tmdb_seasons;
        if (!series || !t)
            return null;
        const last = item.last_air, today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        return t.map(s => ({
                    season: s.season,
                    episodes: last ? (s.season < last.season ? s.episodes : s.season === last.season ? Math.min(s.episodes, last.episode ?? s.episodes) : 0) : (s.air_date && s.air_date <= today ? s.episodes : 0)
                })).filter(s => s.episodes > 0);
    }
    // The episodes on disk, by season
    readonly property var have: {
        const m = {};
        if (series)
            for (const e of item.episodes) {
                m[e.season] = m[e.season] ?? new Set();
                m[e.season].add(e.episode);
            }
        const counts = {};
        for (const k in m)
            counts[k] = m[k].size;
        return counts;
    }
    // Every season there is (aired, or on disk), for the chips
    readonly property var allSeasons: aired ? [...new Set(aired.map(s => s.season).concat(seasons))].sort((a, b) => a - b) : seasons
    // The season's episodes, with their place in the series
    readonly property var shown: series ? item.episodes.map((e, i) => ({
                episode: e,
                index: i
            })).filter(x => x.episode.season === season) : []
    readonly property var next: series ? item.episodes[item.next] ?? null : null

    // The scores Config.reelRatings asks for, in its order, where known; a
    // library from before reel kept more than TMDB's has that one as `rating`
    readonly property var ratings: {
        const r = item?.ratings ?? (item?.rating ? {
                tmdb: item.rating
            } : {});
        return (Config.reelRatings ?? []).filter(k => r[k]).map(k => ({
                    source: k,
                    score: r[k]
                }));
    }

    // Whether a show is on the air, and when it's next on: airing (an
    // episode out in the last fortnight or due in the next three weeks),
    // returning (between seasons), ended, canceled, upcoming
    readonly property var air: {
        const i = item;
        if (!series || !i?.status)
            return null;
        const now = new Date(), day = 24 * 3600 * 1000;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const at = d => d ? new Date(`${d.date}T00:00:00`).getTime() : NaN;
        const next = at(i.next_air), last = at(i.last_air);
        const when = t => {
            const days = Math.round((t - today) / day);
            return days === 0 ? "today" : days === 1 ? "tomorrow" : days > 1 && days < 7 ? Qt.formatDate(new Date(t), "dddd") : Qt.formatDate(new Date(t), new Date(t).getFullYear() === new Date(today).getFullYear() ? "d MMM" : "d MMM yyyy");
        };
        const nextCode = i.next_air?.episode ? `${code(i.next_air)}  ·  ` : "";
        if (i.status === "ended" || i.status === "canceled")
            return {
                state: i.status,
                label: i.status === "ended" ? "Ended" : "Canceled",
                detail: i.last_air ? i.last_air.date.slice(0, 4) : ""
            };
        if (next - today <= 21 * day || (i.status === "returning" && today - last <= 14 * day))
            return {
                state: "airing",
                label: "Airing",
                detail: next >= today ? `${nextCode}${when(next)}` : ""
            };
        if (i.status === "returning")
            return {
                state: "returning",
                label: "Returning",
                detail: next >= today ? `${i.next_air.season ? `Season ${i.next_air.season}  ·  ` : ""}${when(next)}` : ""
            };
        return {
            state: "upcoming",
            label: "Upcoming",
            detail: next >= today ? when(next) : ""
        };
    }

    // Year, length, quality, how far it's been watched; a series', what's
    // here of what has aired ("1 of 10 seasons · 24 of 228 episodes")
    readonly property string summary: {
        const i = item;
        if (!i)
            return "";
        const parts = [i.year || ""];
        if (series) {
            const here = Object.values(have).reduce((a, b) => a + b, 0);
            const out = aired ? aired.reduce((a, s) => a + s.episodes, 0) : 0;
            const n = seasons.length, plural = x => x === 1 ? "season" : "seasons";
            if (!aired || out === 0)
                parts.push(`${n} ${plural(n)}`, `${here} episodes`);
            else if (here >= out && n >= aired.length)
                parts.push(n > 1 ? `${n} seasons` : "", `all ${out} episodes`);
            else
                parts.push(aired.length > 1 ? `${n} of ${aired.length} ${plural(aired.length)}` : "", `${here} of ${out} episodes`);
            const seen = i.episodes.filter(e => e.watched).length;
            if (seen > 0)
                parts.push(`${seen} seen`);
        } else {
            parts.push(i.duration ? runtime(i.duration) : "", quality(i));
            if (i.position > 0)
                parts.push(`${runtime(i.duration - i.position)} left`);
            else if (i.watched)
                parts.push("Seen");
        }
        return parts.filter(x => x !== "").join("  ·  ");
    }

    // "Audio: Japanese    Subtitles: English"
    readonly property string languageLine: {
        const t = item?.tracks;
        const audio = languages("audio"), subs = languages("subs");
        const a = t?.audio ? Languages.name(t.audio) : audio.length === 1 ? Languages.name(audio[0]) : `Automatic (${audio.length})`;
        const s = t?.subs ? Languages.name(t.subs) : subs.length === 0 ? "None" : `Automatic (${subs.length})`;
        return `Audio: ${a}    Subtitles: ${s}`;
    }

    // A movie's details, as [label, value]
    readonly property var details: {
        const i = item;
        if (!i || series)
            return [];
        const audio = languages("audio"), subs = languages("subs");
        return [["Length", i.duration ? runtime(i.duration) : "—"], ["Picture", [quality(i), i.width && i.height ? `${i.width}×${i.height}` : ""].filter(x => x).join("  ·  ") || "—"], ["Audio", audio.map(Languages.name).join(", ") || "—"], ["Subtitles", subs.length > 4 ? `${subs.slice(0, 4).map(Languages.name).join(", ")} and ${subs.length - 4} more` : subs.map(Languages.name).join(", ") || "None"]];
    }

    // "Series · HBO", "Anime", "Movie"
    readonly property string kindLine: {
        const i = item;
        if (!i)
            return "";
        const kind = series ? (i.category === "Anime" ? "Anime" : "Series") : "Movie";
        return series && i.network ? `${kind}  ·  ${i.network}` : kind;
    }

    function airedIn(n) {
        return aired?.find(s => s.season === n)?.episodes ?? 0;
    }

    function code(e) {
        return `S${String(e.season).padStart(2, "0")}E${String(e.episode).padStart(2, "0")}`;
    }

    function runtime(seconds) {
        const m = Math.round(seconds / 60);
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min`;
    }

    function quality(x) {
        const w = x?.width ?? 0, h = x?.height ?? 0;
        return w >= 3200 || h >= 2000 ? "4K" : w >= 1800 || h >= 1000 ? "1080p" : w >= 1200 || h >= 700 ? "720p" : h > 0 ? "SD" : "";
    }

    // The languages it has: a series', every episode's
    function languages(kind) {
        const files = series ? item.episodes : item ? [item] : [];
        return [...new Set(files.reduce((all, f) => all.concat(f[kind] ?? []), []))].sort();
    }
}
