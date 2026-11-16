.pragma library

// What playing a title will do, in words, for the video menu's window mode
// (the hero, the title page's Watch pill): the label ("Resume S02E04",
// "Play again"), what that means ("22 min left · ends at 23:10"), and the
// hero's corner figure. Items are Reel's model's.

function code(e) {
    return `S${String(e.season).padStart(2, "0")}E${String(e.episode).padStart(2, "0")}`;
}

function runtime(seconds) {
    const m = Math.round(seconds / 60);
    return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min`;
}

function seenAll(item) {
    return item.kind === "movie" ? item.watched : item.episodes.length > 0 && item.episodes.every(e => e.watched);
}

// The episode p plays: the one it's up to, else the first
function target(item) {
    if (item?.kind !== "series")
        return null;
    return item.episodes[item.next] ?? item.episodes[0] ?? null;
}

// The clock time it'd end, played now
function endsAt(seconds) {
    return new Date(Date.now() + seconds * 1000).toLocaleTimeString(Qt.locale(), 1);
}

function label(item) {
    if (!item)
        return "";
    if (item.kind === "movie")
        return item.position > 0 ? "Resume" : item.watched ? "Play again" : "Play";
    const e = target(item);
    if (!e)
        return "Play";
    if (item.next >= 0 && item.started)
        return `${e.position > 0 ? "Resume" : "Play"} ${code(e)}`;
    return seenAll(item) ? "Play again" : `Play ${code(e)}`;
}

function sub(item) {
    if (!item)
        return "";
    if (item.kind === "movie") {
        if (item.position > 0)
            return `${runtime(item.duration - item.position)} left  ·  ends at ${endsAt(item.duration - item.position)}`;
        return item.duration ? `${runtime(item.duration)}  ·  ends at ${endsAt(item.duration)}` : "";
    }
    const e = target(item);
    if (!e)
        return "";
    const left = e.position > 0 ? e.duration - e.position : e.duration;
    return [e.title, left ? `${e.position > 0 ? runtime(left) + " left" : runtime(left)}  ·  ends at ${endsAt(left)}` : ""].filter(x => x).join("  ·  ");
}

// Its score, by the first source in `order` (Config.reelRatings) it has,
// else TMDB's
function score(item, order) {
    const r = item?.ratings ?? {};
    for (const k of order ?? [])
        if (r[k])
            return {
                source: k,
                value: Number(r[k])
            };
    return item?.rating ? {
        source: "tmdb",
        value: Number(item.rating)
    } : null;
}

// The hero's corner: how long's left, the episode up next, else the score
function figure(item, order) {
    if (item.kind === "movie" && item.position > 0)
        return ["Left", runtime(item.duration - item.position)];
    if (item.kind === "series" && item.started && item.next >= 0)
        return ["Up next", code(item.episodes[item.next])];
    if (seenAll(item))
        return ["Seen", "All of it"];
    const s = score(item, order);
    if (s && s.source !== "rt" && s.source !== "metacritic")
        return ["Rated", s.value.toFixed(1)];
    if (item.kind === "series")
        return ["Episodes", String(item.episodes.length)];
    return ["Added", item.year || "Lately"];
}

// "Drama  ·  2009  ·  1 h 35 min", or a series' "Animation  ·  2 seasons  ·  24 episodes"
function facts(item, genres) {
    if (!item)
        return "";
    const parts = (item.genres ?? []).slice(0, genres ?? 1);
    if (item.kind === "movie")
        parts.push(item.year || "", item.duration ? runtime(item.duration) : "");
    else {
        const seasons = new Set(item.episodes.map(e => e.season)).size;
        parts.push(seasons > 1 ? `${seasons} seasons` : item.year || "", `${item.episodes.length} episode${item.episodes.length === 1 ? "" : "s"}`);
    }
    return parts.filter(x => x !== "").join("  ·  ");
}
