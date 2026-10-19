// The IDE page must send the saved login with every API request. It was lost once by an over-eager clean-up.
const assert = require("assert");
const html = require("fs").readFileSync(__dirname + "/../ide.html", "utf8");
assert(/Authorization:\s*"Bearer "\s*\+\s*token/.test(html), "ide.html must send the Authorization header");
console.log("ide auth header ok");
