import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = process.cwd();
const required = [
  "AGENTS.md",
  "CLAUDE.md",
  "README.md",
  "docs/STATUS.md",
  "docs/CURSOR_HANDOFF.md",
  "docs/ARCHITECTURE.md",
  "docs/LIT_MONAD_SPIKE.md",
  "web/src/lib/lit-conditions.ts",
  "tool/threshold-spike/conditions.mjs",
  "contracts/README.md",
  "contracts/AGENTS.md",
  "web/README.md",
  "web/AGENTS.md",
  "supabase/README.md",
  "supabase/AGENTS.md",
  ".cursor/rules/00-project.mdc",
  ".cursor/rules/10-contracts.mdc",
  ".cursor/rules/20-web.mdc",
];

const failures = required.filter((file) => !existsSync(join(root, file))).map(
  (file) => `Missing required navigation file: ${file}`,
);

const rootRules = readFileSync(join(root, "AGENTS.md"), "utf8");
if (!rootRules.includes("Would you like to finalize today's work?")) {
  failures.push("AGENTS.md lacks the required finalization prompt.");
}

function visit(directory) {
  for (const item of readdirSync(directory)) {
    if ([".git", "node_modules", ".next", "artifacts", "cache"].includes(item)) continue;
    const fullPath = join(directory, item);
    if (statSync(fullPath).isDirectory()) visit(fullPath);
    else if (item.endsWith(".mdc")) {
      const contents = readFileSync(fullPath, "utf8");
      if (!contents.startsWith("---\n")) {
        failures.push(`Cursor rule lacks front matter: ${relative(root, fullPath)}`);
      }
    }
  }
}
visit(join(root, ".cursor"));

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log("Repository navigation and Cursor handoff checks passed.");
