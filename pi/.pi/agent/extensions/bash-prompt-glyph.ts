/**
 * Bash Prompt Glyph Extension
 *
 * When pi's native bash mode is active (text starts with `!`):
 * - Swaps the prompt character from `>` to `$`
 * - Colors the `$` and the top/bottom border lines red (using theme's bashMode color)
 *
 * Intercepts ctx.ui.setEditorComponent to ensure ANY editor factory
 * installed (including by the powerline footer's internal re-installs)
 * always gets the render patch applied.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const WRAPPED = Symbol("bash-prompt-glyph");

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;

    // Get the theme's bashMode ANSI color code for borders/glyph
    const bashColorAnsi = ctx.ui.theme.getFgAnsi("bashMode");
    const RESET = "\x1b[0m";

    function patchEditorRender(editor: any): void {
      if (!editor || editor[WRAPPED]) return;
      editor[WRAPPED] = true;

      const originalRender = editor.render.bind(editor);
      editor.render = (width: number): string[] => {
        const lines = originalRender(width);

        // Check if editor text starts with ! (pi's native bash mode)
        const text = editor.getText();
        const isBashMode = text.trimStart().startsWith("!");
        if (!isBashMode) return lines;

        // --- Swap glyph and color it ---
        // Powerline renders: \x1b[38;2;200;200;200m>\x1b[0m
        // Replace with bashMode-colored $
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i];
          if (!line) continue;

          const replaced = line.replace(
            /\x1b\[38;2;200;200;200m>\x1b\[0m/,
            `${bashColorAnsi}$${RESET}`
          );

          if (replaced !== line) {
            lines[i] = replaced;
            break;
          }
        }

        // --- Recolor border lines ---
        // Powerline renders borders with sep color (\x1b[38;5;244m) as:
        //   " " + colored("─".repeat(width - 2))
        // We replace the sep color with bashMode color on border lines.
        // Border lines are the first and last lines that are mostly ─ characters.
        const borderRegex = /\x1b\[38;5;244m/g;

        // Top border (first line)
        if (lines[0] && lines[0].includes("─")) {
          lines[0] = lines[0].replace(borderRegex, bashColorAnsi);
        }

        // Bottom border - find last line with ─ (skip autocomplete lines below)
        for (let i = lines.length - 1; i >= 1; i--) {
          if (lines[i] && lines[i].includes("─")) {
            lines[i] = lines[i].replace(borderRegex, bashColorAnsi);
            break;
          }
        }

        return lines;
      };
    }

    function wrapFactory(factory: any): any {
      if (!factory || factory[WRAPPED]) return factory;

      const wrapped = (tui: any, theme: any, keybindings: any) => {
        const editor = factory(tui, theme, keybindings);
        patchEditorRender(editor);
        return editor;
      };
      wrapped[WRAPPED] = true;
      return wrapped;
    }

    // Monkey-patch setEditorComponent so any factory installed by any
    // extension (including powerline footer's internal re-installs)
    // always gets our render patch applied.
    const originalSetEditorComponent = ctx.ui.setEditorComponent.bind(ctx.ui);
    ctx.ui.setEditorComponent = (factory: any) => {
      originalSetEditorComponent(factory ? wrapFactory(factory) : factory);
    };

    // Wrap whatever factory is currently installed
    const existing = ctx.ui.getEditorComponent();
    if (existing && !existing[WRAPPED]) {
      ctx.ui.setEditorComponent(existing); // patched version auto-wraps
    }
  });
}
