import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";

const ASK_USER_PROMPT_EVENT = "rpiv:ask-user:prompt" as const;

export type TmuxAgentStatus = "needs-action" | "done" | "failed";
export type StatusAction = TmuxAgentStatus | "clear";

type RunHelper = (args: string[]) => Promise<unknown>;
type Environment = Record<string, string | undefined>;

export interface StatusWriter {
  set(status: TmuxAgentStatus): Promise<void>;
  clear(): Promise<void>;
  drain(): Promise<void>;
}

export function createStatusWriter(runHelper: RunHelper, enabled = true): StatusWriter {
  let tail: Promise<void> = Promise.resolve();

  const enqueue = (action: StatusAction): Promise<void> => {
    if (!enabled) return Promise.resolve();
    const args = action === "clear" ? ["clear"] : ["set", action];

    tail = tail.then(async () => {
      try {
        await runHelper(args);
      } catch {
        // Attention indicators must never interrupt the agent lifecycle.
      }
    });

    return tail;
  };

  return {
    set: (status) => enqueue(status),
    clear: () => enqueue("clear"),
    drain: () => tail,
  };
}

export interface TmuxAgentStatusController {
  writer: StatusWriter;
}

export function registerTmuxAgentStatus(
  pi: ExtensionAPI,
  env: Environment = process.env,
): TmuxAgentStatusController {
  const helperPath = env.HOME ? join(env.HOME, ".config", "tmux", "scripts", "tmux-agent-status") : "";
  const enabled = Boolean(env.TMUX && env.TMUX_PANE && helperPath);
  const writer = createStatusWriter(
    (args) => pi.exec(helperPath, args, { timeout: 2_000 }),
    enabled,
  );
  let terminalOutcome: "success" | "failed" | "aborted" = "success";

  const unsubscribeAskUser = pi.events.on(ASK_USER_PROMPT_EVENT, () => {
    void writer.set("needs-action");
  });

  pi.on("session_start", () => {
    terminalOutcome = "success";
    return writer.clear();
  });

  pi.on("input", () => writer.clear());

  pi.on("agent_start", () => {
    terminalOutcome = "success";
    return writer.clear();
  });

  pi.on("tool_result", (event) => {
    if (event.toolName === "ask_user_question") return writer.clear();
  });

  pi.on("message_end", (event) => {
    if (event.message.role !== "assistant") return;
    if (event.message.stopReason === "error") terminalOutcome = "failed";
    if (event.message.stopReason === "aborted") terminalOutcome = "aborted";
  });

  pi.on("agent_settled", () => {
    if (terminalOutcome === "failed") return writer.set("failed");
    if (terminalOutcome === "aborted") return writer.clear();
    return writer.set("done");
  });

  pi.on("session_shutdown", async () => {
    unsubscribeAskUser();
    await writer.clear();
  });

  return { writer };
}

export default function tmuxAgentStatusExtension(pi: ExtensionAPI) {
  registerTmuxAgentStatus(pi);
}
