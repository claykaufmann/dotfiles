import { describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  createStatusWriter,
  registerTmuxAgentStatus,
} from "../extensions/tmux-agent-status/index.ts";

const SHARED_HELPER = fileURLToPath(
  new URL("../../../../tmux/.config/tmux/scripts/tmux-agent-status", import.meta.url),
);

type Handler = (event: any, ctx: any) => any;

class FakePi {
  readonly handlers = new Map<string, Handler[]>();
  readonly busHandlers = new Map<string, Set<(data: unknown) => void>>();
  readonly execCalls: Array<{ command: string; args: string[]; timeout?: number }> = [];
  execImpl: (command: string, args: string[]) => Promise<unknown> = async () => ({ code: 0 });

  readonly events = {
    on: (channel: string, handler: (data: unknown) => void) => {
      const handlers = this.busHandlers.get(channel) ?? new Set();
      handlers.add(handler);
      this.busHandlers.set(channel, handlers);
      return () => handlers.delete(handler);
    },
    emit: (channel: string, data: unknown) => {
      for (const handler of this.busHandlers.get(channel) ?? []) handler(data);
    },
  };

  on(event: string, handler: Handler) {
    const handlers = this.handlers.get(event) ?? [];
    handlers.push(handler);
    this.handlers.set(event, handlers);
  }

  async exec(command: string, args: string[], options?: { timeout?: number }) {
    this.execCalls.push({ command, args: [...args], timeout: options?.timeout });
    return this.execImpl(command, args);
  }

  async emit(event: string, payload: Record<string, unknown> = {}) {
    for (const handler of this.handlers.get(event) ?? []) {
      await handler({ type: event, ...payload }, {});
    }
  }

  emitBus(channel: string, data: unknown = {}) {
    this.events.emit(channel, data);
  }

  asExtensionApi(): ExtensionAPI {
    return this as unknown as ExtensionAPI;
  }
}

describe("tmux-agent-status Pi extension", () => {
  test("does nothing when the process is outside tmux", async () => {
    const pi = new FakePi();
    const controller = registerTmuxAgentStatus(pi.asExtensionApi(), { HOME: "/Users/test" });

    await pi.emit("session_start");
    pi.emitBus("rpiv:ask-user:prompt");
    await pi.emit("agent_settled");
    await controller.writer.drain();

    expect(pi.execCalls).toEqual([]);
  });

  test("maps question, answer, input, and settlement events", async () => {
    const pi = new FakePi();
    const controller = registerTmuxAgentStatus(pi.asExtensionApi(), {
      HOME: "/Users/test",
      TMUX: "/tmp/tmux-501/default,1,0",
      TMUX_PANE: "%7",
    });

    await pi.emit("session_start");
    pi.emitBus("rpiv:ask-user:prompt");
    await controller.writer.drain();
    await pi.emit("tool_result", { toolName: "ask_user_question" });
    await pi.emit("input", { source: "interactive", text: "continue" });
    await pi.emit("agent_start");
    await pi.emit("agent_settled");

    expect(pi.execCalls.map((call) => call.args)).toEqual([
      ["clear"],
      ["set", "needs-action"],
      ["clear"],
      ["clear"],
      ["clear"],
      ["set", "done"],
    ]);
    expect(pi.execCalls.every((call) => call.timeout === 2_000)).toBe(true);
    expect(pi.execCalls[0]?.command).toBe("/Users/test/.config/tmux/scripts/tmux-agent-status");
  });

  test("distinguishes failed and aborted terminal outcomes", async () => {
    const pi = new FakePi();
    registerTmuxAgentStatus(pi.asExtensionApi(), {
      HOME: "/Users/test",
      TMUX: "socket",
      TMUX_PANE: "%8",
    });

    await pi.emit("agent_start");
    await pi.emit("message_end", { message: { role: "assistant", stopReason: "error" } });
    await pi.emit("agent_settled");
    await pi.emit("agent_start");
    await pi.emit("message_end", { message: { role: "assistant", stopReason: "aborted" } });
    await pi.emit("agent_settled");

    expect(pi.execCalls.map((call) => call.args)).toEqual([
      ["clear"],
      ["set", "failed"],
      ["clear"],
      ["clear"],
    ]);
  });

  test("serializes writes and swallows helper failures", async () => {
    const calls: string[][] = [];
    const releases: Array<() => void> = [];
    const writer = createStatusWriter(
      (args) => new Promise<void>((resolve) => {
        calls.push([...args]);
        releases.push(resolve);
      }),
    );

    const first = writer.set("needs-action");
    const second = writer.clear();
    await Promise.resolve();
    expect(calls).toEqual([["set", "needs-action"]]);

    releases.shift()?.();
    await first;
    expect(calls).toEqual([["set", "needs-action"], ["clear"]]);
    releases.shift()?.();
    await second;

    const failingWriter = createStatusWriter(async () => {
      throw new Error("tmux unavailable");
    });
    await failingWriter.set("done");
    await failingWriter.drain();
  });

  test("shutdown clears state and unsubscribes from ask-user events", async () => {
    const pi = new FakePi();
    const controller = registerTmuxAgentStatus(pi.asExtensionApi(), {
      HOME: "/Users/test",
      TMUX: "socket",
      TMUX_PANE: "%9",
    });

    pi.emitBus("rpiv:ask-user:prompt");
    await controller.writer.drain();
    await pi.emit("session_shutdown", { reason: "quit" });
    pi.emitBus("rpiv:ask-user:prompt");
    await controller.writer.drain();

    expect(pi.execCalls.map((call) => call.args)).toEqual([
      ["set", "needs-action"],
      ["clear"],
    ]);
  });

  test("drives Pi lifecycle through the real helper on isolated tmux", async () => {
    const root = mkdtempSync(join(tmpdir(), "pi-tmux-agent-status."));
    const socket = `pi-status-${process.pid}-${Date.now()}`;
    const binDir = join(root, "bin");
    const realTmux = execFileSync("which", ["tmux"], { encoding: "utf8" }).trim();
    const tmux = (...args: string[]) => execFileSync(
      realTmux,
      ["-L", socket, "-f", "/dev/null", ...args],
      { encoding: "utf8" },
    ).trimEnd();

    mkdirSync(binDir);
    writeFileSync(
      join(binDir, "tmux"),
      `#!/usr/bin/env bash\nexec ${JSON.stringify(realTmux)} -L ${JSON.stringify(socket)} -f /dev/null "$@"\n`,
    );
    chmodSync(join(binDir, "tmux"), 0o755);

    try {
      tmux("new-session", "-d", "-s", "pi-status");
      const pane = tmux("display-message", "-p", "#{pane_id}");
      const window = tmux("display-message", "-p", "#{window_id}");
      const helperEnv = {
        ...process.env,
        PATH: `${binDir}:${process.env.PATH ?? ""}`,
        TMUX: "isolated-test-server",
        TMUX_PANE: pane,
      };
      const pi = new FakePi();
      pi.execImpl = async (_command, args) => {
        execFileSync("bash", [SHARED_HELPER, ...args], { env: helperEnv });
        return { code: 0 };
      };
      const controller = registerTmuxAgentStatus(pi.asExtensionApi(), {
        HOME: "/Users/test",
        TMUX: "isolated-test-server",
        TMUX_PANE: pane,
      });

      pi.emitBus("rpiv:ask-user:prompt");
      await controller.writer.drain();
      expect(tmux("show-options", "-p", "-q", "-v", "-t", pane, "@ck_agent_status")).toBe("needs-action");

      await pi.emit("tool_result", { toolName: "ask_user_question" });
      expect(tmux("show-options", "-p", "-q", "-v", "-t", pane, "@ck_agent_status")).toBe("");

      await pi.emit("agent_start");
      await pi.emit("agent_settled");
      expect(tmux("show-options", "-p", "-q", "-v", "-t", pane, "@ck_agent_status")).toBe("done");
      expect(execFileSync("bash", [SHARED_HELPER, "render-window", window], {
        env: helperEnv,
        encoding: "utf8",
      }).trimEnd()).toBe(" #[fg=#a6d189]󰄬#[fg=#c6d0f5]");
    } finally {
      try {
        tmux("kill-server");
      } catch {
        // The isolated server may already be gone after a failing assertion.
      }
      rmSync(root, { recursive: true, force: true });
    }
  });
});
