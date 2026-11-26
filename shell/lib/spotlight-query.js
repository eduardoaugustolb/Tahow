.pragma library

function calculate(input) {
    let text = input.trim();
    const explicit = text.startsWith("=");
    if (explicit) text = text.slice(1).trim();
    if (!text || text.length > 160 || (!explicit && !/[+\-*/%^×÷]/.test(text))) return null;
    text = text.replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/");
    const tokens = text.match(/(?:\d+(?:\.\d*)?|\.\d+)|[()+\-*/%^]/g) || [];
    if (tokens.join("") !== text.replace(/\s+/g, "")) return null;

    const precedence = {"+": 1, "-": 1, "*": 2, "/": 2, "%": 2, "^": 3};
    let position = 0;
    function expression(minimum) {
        const first = tokens[position++];
        let value;
        if (first === "+" || first === "-") {
            value = (first === "-" ? -1 : 1) * expression(3);
        } else if (first === "(") {
            value = expression(1);
            if (tokens[position++] !== ")") return NaN;
        } else {
            if (!first || !/^[\d.]/.test(first)) return NaN;
            value = Number(first);
        }

        while (precedence[tokens[position]] >= minimum) {
            const operator = tokens[position++];
            const right = expression(precedence[operator] + (operator === "^" ? 0 : 1));
            if (!Number.isFinite(value) || !Number.isFinite(right)) return NaN;
            switch (operator) {
            case "+": value += right; break;
            case "-": value -= right; break;
            case "*": value *= right; break;
            case "/": value /= right; break;
            case "%": value %= right; break;
            case "^": value **= right; break;
            }
        }
        return value;
    }

    const value = expression(1);
    return position === tokens.length && Number.isFinite(value) ? Number(value.toPrecision(15)) : null;
}

function browserQuery(input) {
    const text = input.trim();
    const forced = text.startsWith("?");
    const query = forced ? text.slice(1).trim() : text;
    if (!query) return null;

    if (!forced && /^https?:\/\/[a-z0-9.-]+(?::\d+)?(?:[/?#][^\s]*)?$/i.test(query))
        return { url: query, direct: true, forced: false };
    if (!forced && /^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}(?::\d+)?(?:[/?#][^\s]*)?$/i.test(query))
        return { url: "https://" + query, direct: true, forced: false };
    return { url: "https://duckduckgo.com/?q=" + encodeURIComponent(query), direct: false, forced };
}
