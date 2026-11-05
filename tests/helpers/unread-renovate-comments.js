// Prints each `# renovate:` comment that no custom manager in a Renovate
// config reads, and exits 1 if there is one. A manager only reads the files
// its managerFilePatterns match, with paths taken relative to <root>.
//
// Usage: node unread-renovate-comments.js <renovate.json> <root> <file>...
const fs = require("node:fs");
const path = require("node:path");

const [configPath, root, ...files] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
const asRegExp = (pattern) => new RegExp(pattern.replace(/^\/(.*)\/$/, "$1"));
const managers = (config.customManagers ?? []).map((manager) => ({
  files: manager.managerFilePatterns.map(asRegExp),
  matchers: manager.matchStrings.map((s) => new RegExp(s, "g")),
}));

let unread = 0;
for (const file of files) {
  const relative = path.relative(root, file);
  const text = fs.readFileSync(file, "utf8");
  const read = new Set(
    managers
      .filter((manager) => manager.files.some((re) => re.test(relative)))
      .flatMap((manager) => manager.matchers.flatMap((re) => [...text.matchAll(re)].map((m) => m.index))),
  );
  for (const comment of text.matchAll(/# renovate:/g)) {
    if (!read.has(comment.index)) {
      console.log(`${relative}: ${text.slice(comment.index).split("\n")[0]}`);
      unread++;
    }
  }
}
process.exit(unread === 0 ? 0 : 1);
