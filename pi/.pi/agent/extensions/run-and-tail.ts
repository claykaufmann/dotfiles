/**
 * Run-and-Tail Extension
 *
 * Gives pi (and you) live visibility into long-running shell commands.
 *
 * The built-in `bash` tool buffers a command and only returns its output when
 * the command finishes, so there is no way to watch progress mid-run (e.g. a
 * slow `pytest` setup). This extension spawns commands in the background,
 * streams their combined stdout/stderr to a log file, and exposes tools to poll
 * the tail while the command is still running.
 *
 * LLM-callable tools:
 *   bg_run   - start a command in the background, returns a job id immediately
 *   bg_tail  - read the most recent output + status for a job
 *   bg_list  - list background jobs and their status
 *   bg_kill  - terminate a running background job
 *
 * User commands (TUI):
 *   /bg              - list background jobs
 *   /bg-tail [id]    - print recent output for a job (defaults to latest)
 *   /bg-kill <id>    - kill a running job
 *
 * While any job is running, a widget above the editor shows each job's status
 * and its latest log line so you can confirm early that things are on track.
 *
 * Logs live under: $TMPDIR/pi-run-and-tail/<pid>/<job-id>.log
 */

import { spawn } from "node:child_process";
import { closeSync, createWriteStream, existsSync, mkdirSync, openSync, readSync, statSync, type WriteStream } from "node:fs";
import { readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

type JobStatus = "running" | "exited" | "error";

interface Job {
	id: string;
	command: string;
	cwd: string;
	logPath: string;
	stream: WriteStream;
	pid?: number;
	startedAt: number;
	endedAt?: number;
	status: JobStatus;
	exitCode?: number | null;
	errorMessage?: string;
	kill: () => void;
}

const WIDGET_ID = "run-and-tail";
const isWindows = process.platform === "win32";

export default function runAndTailExtension(pi: ExtensionAPI) {
	const jobs = new Map<string, Job>();
	let counter = 0;
	let logDir: string | undefined;
	let widgetCtx: ExtensionContext | undefined;
	let widgetTimer: NodeJS.Timeout | undefined;

	const getLogDir = (): string => {
		if (!logDir) {
			logDir = join(tmpdir(), "pi-run-and-tail", String(process.pid));
			mkdirSync(logDir, { recursive: true });
		}
		return logDir;
	};

	const latestJob = (): Job | undefined => {
		let latest: Job | undefined;
		for (const job of jobs.values()) {
			if (!latest || job.startedAt > latest.startedAt) latest = job;
		}
		return latest;
	};

	const hasRunningJobs = (): boolean => {
		for (const job of jobs.values()) if (job.status === "running") return true;
		return false;
	};

	// Read up to the last `maxBytes` of a file, then return the last `lines` lines.
	const readTail = async (path: string, lines: number, maxBytes = 256 * 1024): Promise<string> => {
		if (!existsSync(path)) return "";
		const size = statSync(path).size;
		if (size === 0) return "";
		if (size <= maxBytes) {
			const text = await readFile(path, "utf8");
			return lastLines(text, lines);
		}
		// Large file: read only the trailing window.
		const fd = openSync(path, "r");
		try {
			const start = size - maxBytes;
			const buf = Buffer.alloc(maxBytes);
			readSync(fd, buf, 0, maxBytes, start);
			// Drop the first (likely partial) line.
			const text = buf.toString("utf8").replace(/^[^\n]*\n/, "");
			return lastLines(text, lines);
		} finally {
			closeSync(fd);
		}
	};

	const startWidgetLoop = () => {
		if (widgetTimer) return;
		widgetTimer = setInterval(() => void refreshWidget(), 1000);
		// Do not keep the process alive just for the widget.
		widgetTimer.unref?.();
	};

	const stopWidgetLoop = () => {
		if (widgetTimer) {
			clearInterval(widgetTimer);
			widgetTimer = undefined;
		}
	};

	const lastLogLine = (path: string): string => {
		try {
			if (!existsSync(path) || statSync(path).size === 0) return "";
			const size = statSync(path).size;
			const window = Math.min(size, 8 * 1024);
			const fd = openSync(path, "r");
			try {
				const buf = Buffer.alloc(window);
				readSync(fd, buf, 0, window, size - window);
				const lines = buf.toString("utf8").split(/\r?\n/).filter((l) => l.trim().length > 0);
				return lines.length ? lines[lines.length - 1] : "";
			} finally {
				closeSync(fd);
			}
		} catch {
			return "";
		}
	};

	const refreshWidget = async () => {
		const ctx = widgetCtx;
		if (!ctx?.hasUI) return;
		const now = Date.now();
		const rows: string[] = [];
		for (const job of [...jobs.values()].sort((a, b) => a.startedAt - b.startedAt)) {
			// Drop finished jobs from the widget 5s after they end.
			if (job.status !== "running" && job.endedAt && now - job.endedAt > 5000) continue;
			const icon = job.status === "running" ? "⟳" : job.status === "error" ? "✗" : job.exitCode === 0 ? "✓" : "✗";
			const secs = Math.round(((job.endedAt ?? now) - job.startedAt) / 1000);
			const head = `${icon} ${job.id} (${secs}s) ${truncate(job.command, 48)}`;
			const tail = job.status === "running" ? truncate(lastLogLine(job.logPath), 60) : job.status === "error" ? job.errorMessage ?? "spawn error" : `exit ${job.exitCode}`;
			rows.push(tail ? `${head}  ·  ${tail}` : head);
		}
		if (rows.length === 0) {
			ctx.ui.setWidget(WIDGET_ID, []);
			if (!hasRunningJobs()) stopWidgetLoop();
			return;
		}
		ctx.ui.setWidget(WIDGET_ID, ["Background jobs:", ...rows]);
	};

	const spawnJob = (command: string, cwd: string): Job => {
		counter += 1;
		const id = `bg-${counter}`;
		const logPath = join(getLogDir(), `${id}.log`);
		const stream = createWriteStream(logPath, { flags: "w" });
		stream.write(`$ ${command}\n`);

		const child = spawn(command, {
			cwd,
			shell: true,
			env: process.env,
			stdio: ["ignore", "pipe", "pipe"],
			// Own process group on POSIX so we can kill the whole tree.
			detached: !isWindows,
		});

		const job: Job = {
			id,
			command,
			cwd,
			logPath,
			stream,
			pid: child.pid,
			startedAt: Date.now(),
			status: "running",
			kill: () => {
				try {
					if (!isWindows && child.pid) process.kill(-child.pid, "SIGTERM");
					else child.kill("SIGTERM");
				} catch {
					try {
						child.kill("SIGKILL");
					} catch {
						/* already gone */
					}
				}
			},
		};

		child.stdout?.on("data", (d) => stream.write(d));
		child.stderr?.on("data", (d) => stream.write(d));
		child.on("error", (err) => {
			job.status = "error";
			job.errorMessage = err.message;
			job.endedAt = Date.now();
			stream.write(`\n[spawn error] ${err.message}\n`);
			stream.end();
			void refreshWidget();
		});
		child.on("exit", (code) => {
			if (job.status === "error") return;
			job.status = "exited";
			job.exitCode = code;
			job.endedAt = Date.now();
			stream.write(`\n[process exited with code ${code}]\n`);
			stream.end();
			void refreshWidget();
		});

		jobs.set(id, job);
		startWidgetLoop();
		void refreshWidget();
		return job;
	};

	// ---- Lifecycle ---------------------------------------------------------

	pi.on("session_start", (_event, ctx) => {
		widgetCtx = ctx;
		if (hasRunningJobs()) startWidgetLoop();
	});

	pi.on("session_shutdown", () => {
		stopWidgetLoop();
		for (const job of jobs.values()) {
			if (job.status === "running") job.kill();
		}
		widgetCtx?.ui.setWidget(WIDGET_ID, []);
		widgetCtx = undefined;
	});

	// ---- Tools -------------------------------------------------------------

	pi.registerTool({
		name: "bg_run",
		label: "Background Run",
		description:
			"Start a shell command in the background and return immediately with a job id. " +
			"Combined stdout/stderr is streamed to a log file. Use bg_tail to poll progress " +
			"while the command is still running. Ideal for long-running commands (test suites, " +
			"builds, dev servers, data downloads) where you want to confirm early that things " +
			"are on track instead of blocking on a single long bash call.",
		promptSnippet: "Run a long command in the background; poll it with bg_tail",
		promptGuidelines: [
			"Use bg_run instead of bash for commands expected to take more than ~30s (test suites, builds, installs), then poll bg_tail to verify early progress before waiting for completion.",
			"After bg_run, call bg_tail periodically to check output and status rather than assuming success.",
		],
		parameters: Type.Object({
			command: Type.String({ description: "Shell command to run in the background" }),
			cwd: Type.Optional(Type.String({ description: "Working directory (defaults to the session cwd)" })),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const cwd = params.cwd ?? ctx.cwd;
			const job = spawnJob(params.command, cwd);
			return {
				content: [
					{
						type: "text",
						text:
							`Started background job ${job.id} (pid ${job.pid ?? "?"}).\n` +
							`cwd: ${cwd}\n` +
							`log: ${job.logPath}\n\n` +
							`Poll progress with bg_tail { "job_id": "${job.id}" }.`,
					},
				],
				details: { jobId: job.id, pid: job.pid, logPath: job.logPath, command: params.command, cwd },
			};
		},
	});

	pi.registerTool({
		name: "bg_tail",
		label: "Background Tail",
		description:
			"Read the most recent output and current status of a background job started with bg_run. " +
			"Defaults to the most recently started job and the last 40 lines of output.",
		promptSnippet: "Poll recent output + status of a bg_run job",
		parameters: Type.Object({
			job_id: Type.Optional(Type.String({ description: "Job id (defaults to the latest job)" })),
			lines: Type.Optional(Type.Number({ description: "Number of trailing lines to return (default 40)" })),
		}),
		async execute(_toolCallId, params) {
			const job = params.job_id ? jobs.get(params.job_id) : latestJob();
			if (!job) {
				throw new Error(params.job_id ? `No background job with id "${params.job_id}"` : "No background jobs have been started");
			}
			const n = Math.max(1, Math.min(params.lines ?? 40, 1000));
			const tail = await readTail(job.logPath, n);
			const statusLine =
				job.status === "running"
					? `status: running (pid ${job.pid}, ${Math.round((Date.now() - job.startedAt) / 1000)}s elapsed)`
					: job.status === "error"
						? `status: error — ${job.errorMessage ?? "spawn failed"}`
						: `status: exited (code ${job.exitCode}, ran ${Math.round(((job.endedAt ?? Date.now()) - job.startedAt) / 1000)}s)`;
			return {
				content: [
					{
						type: "text",
						text: `${job.id} — ${job.command}\n${statusLine}\n\n--- last ${n} lines ---\n${tail || "(no output yet)"}`,
					},
				],
				details: { jobId: job.id, status: job.status, exitCode: job.exitCode ?? null },
			};
		},
	});

	pi.registerTool({
		name: "bg_list",
		label: "Background List",
		description: "List background jobs started with bg_run and their current status.",
		promptSnippet: "List background jobs and their status",
		parameters: Type.Object({}),
		async execute() {
			if (jobs.size === 0) {
				return { content: [{ type: "text", text: "No background jobs." }], details: { jobs: [] } };
			}
			const now = Date.now();
			const rows = [...jobs.values()]
				.sort((a, b) => a.startedAt - b.startedAt)
				.map((job) => {
					const secs = Math.round(((job.endedAt ?? now) - job.startedAt) / 1000);
					const status =
						job.status === "running" ? `running ${secs}s` : job.status === "error" ? `error: ${job.errorMessage}` : `exit ${job.exitCode} (${secs}s)`;
					return `${job.id}\t${status}\t${job.command}`;
				});
			return {
				content: [{ type: "text", text: `id\tstatus\tcommand\n${rows.join("\n")}` }],
				details: {
					jobs: [...jobs.values()].map((j) => ({ id: j.id, status: j.status, exitCode: j.exitCode ?? null, command: j.command })),
				},
			};
		},
	});

	pi.registerTool({
		name: "bg_kill",
		label: "Background Kill",
		description: "Terminate a running background job started with bg_run.",
		promptSnippet: "Kill a running bg_run job",
		parameters: Type.Object({
			job_id: Type.String({ description: "Job id to terminate" }),
		}),
		async execute(_toolCallId, params) {
			const job = jobs.get(params.job_id);
			if (!job) throw new Error(`No background job with id "${params.job_id}"`);
			if (job.status !== "running") {
				return { content: [{ type: "text", text: `${job.id} is not running (status: ${job.status}).` }], details: { jobId: job.id } };
			}
			job.kill();
			return { content: [{ type: "text", text: `Sent SIGTERM to ${job.id}.` }], details: { jobId: job.id } };
		},
	});

	// ---- User commands -----------------------------------------------------

	pi.registerCommand("bg", {
		description: "List background jobs (run-and-tail)",
		handler: async (_args, ctx) => {
			if (jobs.size === 0) {
				ctx.ui.notify("No background jobs.", "info");
				return;
			}
			const now = Date.now();
			const lines = [...jobs.values()]
				.sort((a, b) => a.startedAt - b.startedAt)
				.map((job) => {
					const secs = Math.round(((job.endedAt ?? now) - job.startedAt) / 1000);
					const status = job.status === "running" ? `running ${secs}s` : job.status === "error" ? "error" : `exit ${job.exitCode}`;
					return `${job.id} [${status}] ${truncate(job.command, 50)}`;
				});
			ctx.ui.notify(lines.join("\n"), "info");
		},
	});

	pi.registerCommand("bg-tail", {
		description: "Show recent output of a background job: /bg-tail [job-id]",
		handler: async (args, ctx) => {
			const job = args.trim() ? jobs.get(args.trim()) : latestJob();
			if (!job) {
				ctx.ui.notify(args.trim() ? `No job "${args.trim()}"` : "No background jobs.", "warning");
				return;
			}
			const tail = await readTail(job.logPath, 30);
			ctx.ui.notify(`${job.id} (${job.status})\n${tail || "(no output yet)"}`, "info");
		},
	});

	pi.registerCommand("bg-kill", {
		description: "Kill a running background job: /bg-kill <job-id>",
		handler: async (args, ctx) => {
			const id = args.trim();
			const job = id ? jobs.get(id) : undefined;
			if (!job) {
				ctx.ui.notify("Usage: /bg-kill <job-id>", "warning");
				return;
			}
			if (job.status !== "running") {
				ctx.ui.notify(`${job.id} is not running.`, "warning");
				return;
			}
			job.kill();
			ctx.ui.notify(`Sent SIGTERM to ${job.id}.`, "info");
		},
	});
}

function lastLines(text: string, n: number): string {
	const lines = text.split(/\r?\n/);
	// Drop a trailing empty line from a final newline.
	if (lines.length && lines[lines.length - 1] === "") lines.pop();
	return lines.slice(-n).join("\n");
}

function truncate(s: string, max: number): string {
	const clean = s.replace(/\s+/g, " ").trim();
	return clean.length > max ? `${clean.slice(0, max - 1)}…` : clean;
}
