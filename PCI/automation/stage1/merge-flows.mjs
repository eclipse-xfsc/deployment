import { readFile, writeFile } from "node:fs/promises";

const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, all) => {
  if (value.startsWith("--")) pairs.push([value.slice(2), all[index + 1]]);
  return pairs;
}, []));
if (!args.existing || !args.incoming || !args.output) throw new Error("Usage: merge-flows.mjs --existing FILE --incoming FILE --output FILE");
const existing = JSON.parse(await readFile(args.existing, "utf8"));
const incoming = JSON.parse(await readFile(args.incoming, "utf8"));
const incomingIds = new Set(incoming.map((node) => node.id));
const pciTabs = new Set(existing.filter((node) => node.type === "tab" && (node.label === "PCI_Interface" || /^M\d+_PCI-/.test(node.label || ""))).map((node) => node.id));
for (const node of existing) {
  if (incomingIds.has(node.id) && !pciTabs.has(node.id) && !pciTabs.has(node.z)) {
    const expected=incoming.find(n=>n.id===node.id);
    // Global PCI configuration nodes have no tab; accept only their existing PCI name.
    if (node.z || !String(node.name||'').startsWith('PCI') || node.type!==expected.type) throw new Error('PCI-INSTALL-NODE-ID-COLLISION');
  }
  if (node.type==='uibuilder' && node.url==='ui' && !pciTabs.has(node.z) && !incomingIds.has(node.id)) throw new Error('PCI-INSTALL-UI-PATH-COLLISION');
}
const retained = existing.filter((node) => !incomingIds.has(node.id) && !pciTabs.has(node.id) && !pciTabs.has(node.z));
const merged = [...retained, ...incoming];
const seen = new Set();
for (const node of merged) {
  if (!node.id) throw new Error("Flow node without id");
  if (seen.has(node.id)) throw new Error(`Duplicate flow id ${node.id}`);
  seen.add(node.id);
}
await writeFile(args.output, `${JSON.stringify(merged, null, 2)}\n`);
console.log(JSON.stringify({ retained: retained.length, imported: incoming.length, total: merged.length }));
