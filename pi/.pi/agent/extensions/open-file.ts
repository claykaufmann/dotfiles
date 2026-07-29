import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { resolve } from "node:path";
import { access } from "node:fs/promises";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("open", {
    description: "Open a file in the default application (browser for HTML)",
    handler: async (args, ctx) => {
      const filePath = args?.trim().replace(/^@/, "");
      if (!filePath) {
        ctx.ui.notify("Usage: /open <path>", "warning");
        return;
      }

      const resolved = resolve(ctx.cwd, filePath);

      try {
        await access(resolved);
      } catch {
        ctx.ui.notify(`File not found: ${resolved}`, "error");
        return;
      }

      const result = await pi.exec("open", [resolved]);
      if (result.code === 0) {
        ctx.ui.notify(`Opened: ${resolved}`, "info");
      } else {
        ctx.ui.notify(`Failed to open: ${result.stderr}`, "error");
      }
    },
  });
}
