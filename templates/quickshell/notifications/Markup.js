.pragma library

// Small notification markup subset; never forward attributes, links or image URLs.
function escapeText(value) {
    const entities = {amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: "\u00a0"};
    return value.replace(/&(#x[0-9a-f]+|#[0-9]+|amp|lt|gt|quot|apos|nbsp);/gi, function(match, key) {
        if (key[0] !== "#") return entities[key.toLowerCase()];
        const code = key[1].toLowerCase() === "x" ? parseInt(key.slice(2), 16) : parseInt(key.slice(1), 10);
        return code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff) ? String.fromCodePoint(code) : "\ufffd";
    }).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/\r\n?|\n/g, "<br>");
}

function normalize(value) {
    const source = String(value || "")
        .replace(/<!--[\s\S]*?(?:-->|$)/g, "")
        .replace(/<(script|style)\b[^>]*>[\s\S]*?(?:<\/\1\s*>|$)/gi, "");
    const tags = /<\/?[a-z](?:[^>"']|"[^"]*"|'[^']*')*(?:>|$)/gi;
    let result = "", position = 0, match;
    const stack = [];
    function lineBreak() { if (result && !result.endsWith("<br>")) result += "<br>"; }
    while ((match = tags.exec(source)) !== null) {
        result += escapeText(source.slice(position, match.index));
        position = tags.lastIndex;
        const name = /^<\/?([a-z][a-z0-9]*)/i.exec(match[0])[1].toLowerCase();
        const closing = match[0][1] === "/";
        const heading = /^h[1-6]$/.test(name);
        const mapped = heading ? "b" : name;
        if (name === "br" || name === "p" || name === "div") {
            lineBreak();
        } else if (["b", "i", "u"].indexOf(mapped) !== -1) {
            if (heading && !closing) lineBreak();
            if (closing) {
                const index = stack.map(t => t.name).lastIndexOf(name);
                if (index >= 0) while (stack.length > index) result += "</" + stack.pop().mapped + ">";
            } else if (match[0].endsWith(">") && stack.length < 32) {
                result += "<" + mapped + ">"; stack.push({name: name, mapped: mapped});
            }
            if (heading && closing) lineBreak();
        } else if (name === "img" && !closing) {
            const alt = /\balt\s*=\s*(?:"([^"]*)"|'([^']*)')/i.exec(match[0]);
            if (alt) result += escapeText(alt[1] === undefined ? alt[2] : alt[1]);
        }
        // Other tags are unwrapped; their textual content is processed normally.
    }
    result += escapeText(source.slice(position));
    while (stack.length) result += "</" + stack.pop().mapped + ">";
    return result.replace(/(?:<br>)+$/, "");
}
