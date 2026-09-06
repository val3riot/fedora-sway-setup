.pragma library
function score(name, query) {
    name = name.toLocaleLowerCase(); query = query.trim().toLocaleLowerCase();
    if (!query) return 0;
    const at = name.indexOf(query);
    if (at >= 0) return at === 0 ? 0 : 10 + at;
    let position = -1, total = 100;
    for (const letter of query) {
        position = name.indexOf(letter, position + 1);
        if (position < 0) return -1;
        total += position;
    }
    return total;
}
function rank(items, query) {
    return items.map((item, index) => ({item: item, index: index, score: score(item.name, query)}))
        .filter(row => row.score >= 0)
        .sort((a, b) => a.score - b.score || a.index - b.index).map(row => row.item);
}
