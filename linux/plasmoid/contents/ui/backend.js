.pragma library

function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
}

function command(bin, args) {
    var parts = [shellQuote(bin)]
    for (var i = 0; i < args.length; i++) {
        parts.push(shellQuote(args[i]))
    }
    return parts.join(" ")
}
