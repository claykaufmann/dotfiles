import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join, parse } from "node:path";

/**
 * Block direct pytest invocations in repos that define a `just test` recipe,
 * steering the agent to `just test` / `just test-parallel-fast` instead.
 *
 * Advisory instructions (AGENTS.md / skills) get ignored; this is a hard guard.
 * Scoped so it only fires in projects that actually have a `just test` recipe,
 * leaving plain `pytest` usage in other repos untouched.
 */

// pytest, python -m pytest, uv run pytest, poetry run pytest, pipenv run pytest, ...
const DIRECT_PYTEST =
  /(^|[\s;&|(])((uv|poetry|pipenv|pdm|hatch)\s+run\s+|python3?\s+-m\s+)?pytest(\s|$|['"])/;

// Cache: directory -> whether an ancestor justfile defines a `test` recipe.
const justTestCache = new Map<string, boolean>();

function findJustfile(startDir: string): string | null {
  let dir = startDir;
  const root = parse(dir).root;
  while (true) {
    for (const name of ["justfile", "Justfile", ".justfile"]) {
      const candidate = join(dir, name);
      if (existsSync(candidate)) return candidate;
    }
    if (dir === root) return null;
    dir = dirname(dir);
  }
}

function repoUsesJustTest(cwd: string): boolean {
  if (justTestCache.has(cwd)) return justTestCache.get(cwd)!;
  let result = false;
  try {
    const justfile = findJustfile(cwd);
    if (justfile) {
      const contents = readFileSync(justfile, "utf8");
      // A recipe named `test` at the start of a line, e.g. `test *ARGS:` / `test:`
      result = /^test\b[^\n]*:/m.test(contents);
    }
  } catch {
    result = false;
  }
  justTestCache.set(cwd, result);
  return result;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const cmd = event.input.command ?? "";
    if (!DIRECT_PYTEST.test(cmd)) return;

    // Already going through the justfile — allow it.
    if (/\bjust\s+(test|ee)\b/.test(cmd) || /\bjust\s+test-/.test(cmd)) return;

    if (!repoUsesJustTest(ctx.cwd)) return;

    return {
      block: true,
      reason:
        "Direct pytest is disallowed in this repo — run tests through the justfile.\n" +
        "  • Full suite / many tests:  just test-parallel-fast\n" +
        "  • Single file / test / -k:  just test <path-or-args>\n" +
        "See .claude/skills/test/SKILL.md for details. Reissue the command using `just test`.",
    };
  });
}
