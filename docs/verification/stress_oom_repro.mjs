// Reproduces JSON.parse() V8 heap growth/crash vs. BloatStrip ~64 MB ring-buffer streaming.
import { writeFileSync, readFileSync, statSync } from "node:fs";

const args = process.argv.slice(2);
const mbIdx = args.indexOf("--mb");
const mb = mbIdx >= 0 ? Number(args[mbIdx + 1]) : 50;
const bench = args.includes("--bench");
const outPath = "dummy_takeout.json";

const record = JSON.stringify({
  header: "Gemini Apps",
  title: "Prompted Analyze large dataset batch performance",
  time: "2026-11-20T12:00:00.000Z",
  products: ["Gemini Apps"],
  safeHtmlItem: [
    {
      html: "<p>Synthetic assistant payload replicating HTML wrapper overhead and object-tree heap bloat.</p>".repeat(4),
    },
  ],
});

const targetBytes = mb * 1024 * 1024;
const chunks = ["["];
let bytes = 1;
let count = 0;
while (bytes < targetBytes) {
  if (count > 0) chunks.push(",");
  chunks.push(record);
  bytes += record.length + (count > 0 ? 1 : 0);
  count += 1;
}
chunks.push("]");
writeFileSync(outPath, chunks.join(""), "utf8");
const actualMb = (statSync(outPath).size / (1024 * 1024)).toFixed(1);
console.log(`Generated ${outPath}: ${actualMb} MB (${count} records)`);

if (bench) {
  const t0 = performance.now();
  const parsed = JSON.parse(readFileSync(outPath, "utf8"));
  const dt = ((performance.now() - t0) / 1000).toFixed(3);
  const heapMb = (process.memoryUsage().heapUsed / (1024 * 1024)).toFixed(1);
  console.log(`Node JSON.parse(): records=${parsed.length} elapsed=${dt}s heapUsed=${heapMb} MB`);
}
