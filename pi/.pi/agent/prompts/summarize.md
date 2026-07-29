---
description: Summarize prior findings or this session into a self-contained, interactive HTML report
argument-hint: "[topic-or-focus]"
---

Produce a single self-contained HTML report that summarizes **$ARGUMENTS** (or a chosen scope of this session's findings). Save it under `./.pi/summaries/` in the current repo. Do **not** reply with the full contents in chat — after writing, reply with only: the path, a one-line summary of what you captured, and any open questions.

## Ambiguity handling

If `$ARGUMENTS` is empty, **stop and ask first** before doing anything else. Offer 2–4 concrete options derived from what's actually in the session (e.g. "the /trace output for X", "the design discussion about Y", "the whole session so far"). One crisp question, then wait.

If `$ARGUMENTS` is non-empty, commit and build. If you hit ambiguity mid-run, pick the most likely interpretation, note it in the report's **Summary**, and list alternatives under **Open questions**.

## What to summarize

Pull from, in this order of preference:

1. **Explicit findings already in this session** — e.g. the output of an earlier `/trace`, research skill results, code-review notes, design documents the user wrote or agents produced. These are authoritative; do not re-investigate unless a claim is unverifiable.
2. **Files and paths already read in the session** — treat them as primary sources. Cite them as `path/to/file.ext:line`.
3. **Targeted fresh reads** — only if the summary has a clear gap you must fill. Keep this narrow.

Do **not** launch a full investigation for `/summarize`. If the session is thin and you'd have to do the bulk of the work yourself, say so in the Summary and suggest the user run `/trace` (or the `research` skill) first.

## Required structure

The HTML should include, where relevant:

1. **Overview** — one paragraph: what this summary is about and the scope (session-wide, one trace, one feature).
2. **Key findings** — the 3–7 things most worth remembering. Each finding links to supporting sections.
3. **Data model** — tables, key columns, FKs, enums, constraints (if relevant to scope).
4. **API / services** — endpoints or service functions, request/response shape, auth notes.
5. **Frontend** — screens, hooks, stores, generated client types.
6. **Link map** — a Mermaid diagram showing DB → API → frontend (or the equivalent for the scope). Include a second diagram for any cross-module couplings that surprised you.
7. **Open questions** — ambiguities, unverified claims, follow-ups.
8. **Sources** — a list of `path/to/file.ext:line` references used, grouped by section.

Omit sections that don't apply. Prefer short, dense bullets over prose. Every non-trivial claim should cite a path.

## Output format — interactive single-file HTML

Write **one file** to `./.pi/summaries/<slug>-<YYYYMMDD-HHMMSS>.html`. Create the directory if it doesn't exist (`mkdir -p ./.pi/summaries`). Slug is a short kebab-case version of the topic (e.g. `ncr-containers`, `auth-flow`).

Use this skeleton. Fill in the `{{…}}` placeholders and replicate `<section>` blocks as needed. Keep it self-contained: no local assets, no build step. Mermaid is loaded from a CDN with a graceful fallback (if the CDN fails, the diagram source remains visible in the `<pre>` block).

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>{{TITLE}} — Summary</title>
<style>
  :root {
    --bg: #0f1115; --fg: #e6e6e6; --muted: #8a93a6; --accent: #6aa9ff;
    --card: #171a21; --border: #262b36; --code-bg: #0b0d12; --warn: #e6b450;
  }
  @media (prefers-color-scheme: light) {
    :root { --bg:#fafafa; --fg:#1a1a1a; --muted:#555; --accent:#1e66d0;
            --card:#fff; --border:#e2e5ea; --code-bg:#f3f4f7; --warn:#b8860b; }
  }
  * { box-sizing: border-box; }
  body { margin:0; font:14px/1.55 ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
         color:var(--fg); background:var(--bg); }
  header { position:sticky; top:0; z-index:10; background:var(--bg); border-bottom:1px solid var(--border);
           padding:12px 20px; display:flex; gap:16px; align-items:center; flex-wrap:wrap; }
  header h1 { font-size:16px; margin:0; }
  header .meta { color:var(--muted); font-size:12px; }
  header input { flex:1; min-width:200px; padding:6px 10px; border-radius:6px;
                 border:1px solid var(--border); background:var(--card); color:var(--fg); }
  main { display:grid; grid-template-columns: 240px 1fr; max-width:1200px; margin:0 auto; }
  nav { position:sticky; top:64px; align-self:start; padding:16px; border-right:1px solid var(--border); max-height:calc(100vh - 64px); overflow:auto; }
  nav a { display:block; color:var(--muted); text-decoration:none; padding:4px 0; font-size:13px; }
  nav a:hover, nav a.active { color:var(--accent); }
  article { padding:20px 28px; }
  section { margin-bottom:28px; scroll-margin-top: 72px; }
  section > h2 { margin:0 0 12px; font-size:18px; display:flex; align-items:center; gap:8px; cursor:pointer; }
  section > h2 .chev { font-size:12px; color:var(--muted); transition:transform .15s; }
  section.collapsed > h2 .chev { transform:rotate(-90deg); }
  section.collapsed > .body { display:none; }
  .card { background:var(--card); border:1px solid var(--border); border-radius:8px; padding:12px 14px; margin:8px 0; }
  ul { margin:6px 0; padding-left:20px; }
  li { margin:3px 0; }
  code { background:var(--code-bg); padding:1px 5px; border-radius:4px; font-size:12.5px; }
  pre { background:var(--code-bg); padding:10px 12px; border-radius:6px; overflow:auto; position:relative; }
  pre .copy { position:absolute; top:6px; right:6px; font-size:11px; background:var(--border); color:var(--fg);
              border:0; padding:3px 7px; border-radius:4px; cursor:pointer; opacity:0; transition:opacity .15s; }
  pre:hover .copy { opacity:1; }
  .path { color:var(--accent); font-family:ui-monospace,Menlo,monospace; font-size:12.5px; }
  .tag { display:inline-block; padding:1px 6px; border-radius:10px; font-size:11px;
         background:var(--border); color:var(--muted); margin-left:6px; }
  .warn { border-left:3px solid var(--warn); padding-left:10px; color:var(--warn); }
  .mermaid { background:var(--card); border:1px solid var(--border); border-radius:8px; padding:10px; }
  .hidden { display:none !important; }
  @media (max-width:860px) { main { grid-template-columns:1fr; } nav { position:static; border-right:0; border-bottom:1px solid var(--border); max-height:none; } }
</style>
</head>
<body>

<header>
  <h1>{{TITLE}}</h1>
  <span class="meta">{{SCOPE}} · {{GENERATED_AT}}</span>
  <input id="filter" type="search" placeholder="Filter sections and bullets…" aria-label="Filter" />
</header>

<main>
  <nav id="toc"><!-- auto-generated from <section id=""> --></nav>

  <article>

    <section id="overview">
      <h2><span class="chev">▾</span> Overview</h2>
      <div class="body">
        <p>{{ONE_PARAGRAPH_OVERVIEW}}</p>
      </div>
    </section>

    <section id="key-findings">
      <h2><span class="chev">▾</span> Key findings</h2>
      <div class="body">
        <ul>
          <li>{{FINDING}} — see <a href="#data-model">data model</a></li>
          <!-- repeat -->
        </ul>
      </div>
    </section>

    <section id="data-model">
      <h2><span class="chev">▾</span> Data model</h2>
      <div class="body">
        <div class="card">
          <strong>{{table_name}}</strong> <span class="path">{{path/to/model.py}}</span>
          <ul>
            <li><code>{{column}}</code>: {{type}}, {{nullability}}, {{default}}</li>
          </ul>
        </div>
      </div>
    </section>

    <section id="api">
      <h2><span class="chev">▾</span> API / services</h2>
      <div class="body">
        <div class="card">
          <code>{{METHOD}} {{/path}}</code> → <span class="path">{{handler.py:line}}</span>
          <ul>
            <li>Input: {{schema}}</li>
            <li>Output: {{schema}}</li>
            <li>Auth: {{notes}}</li>
          </ul>
        </div>
      </div>
    </section>

    <section id="frontend">
      <h2><span class="chev">▾</span> Frontend</h2>
      <div class="body">
        <ul>
          <li><span class="path">{{Screen.tsx}}</span> — {{what it does}}</li>
        </ul>
      </div>
    </section>

    <section id="link-map">
      <h2><span class="chev">▾</span> Link map</h2>
      <div class="body">
        <pre class="mermaid">
flowchart LR
  DB[(table)] --> API[handler] --> FE[Screen]
        </pre>
        <!-- add a second mermaid block for surprising cross-module couplings -->
      </div>
    </section>

    <section id="open-questions">
      <h2><span class="chev">▾</span> Open questions</h2>
      <div class="body">
        <ul>
          <li class="warn">{{question}}</li>
        </ul>
      </div>
    </section>

    <section id="sources">
      <h2><span class="chev">▾</span> Sources</h2>
      <div class="body">
        <ul>
          <li><span class="path">{{path/to/file.ext:line}}</span> <span class="tag">{{section}}</span></li>
        </ul>
      </div>
    </section>

  </article>
</main>

<script type="module">
  // Mermaid with graceful fallback — if CDN fails, <pre class="mermaid"> blocks remain readable.
  try {
    const m = await import("https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs");
    m.default.initialize({ startOnLoad: false, theme: matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "default" });
    await m.default.run({ nodes: document.querySelectorAll(".mermaid") });
  } catch (e) {
    document.querySelectorAll(".mermaid").forEach(el => {
      const note = document.createElement("div");
      note.className = "warn";
      note.textContent = "Mermaid CDN unavailable — showing diagram source below.";
      el.parentNode.insertBefore(note, el);
    });
  }
</script>

<script>
  // Build TOC from sections.
  const toc = document.getElementById("toc");
  document.querySelectorAll("article section").forEach(s => {
    const h = s.querySelector("h2");
    const a = document.createElement("a");
    a.href = "#" + s.id;
    a.textContent = h.textContent.replace(/^▾\s*/, "").trim();
    toc.appendChild(a);
  });

  // Collapsible sections.
  document.querySelectorAll("article section > h2").forEach(h => {
    h.addEventListener("click", () => h.parentElement.classList.toggle("collapsed"));
  });

  // Copy buttons on <pre>.
  document.querySelectorAll("pre").forEach(pre => {
    if (pre.classList.contains("mermaid")) return;
    const b = document.createElement("button");
    b.className = "copy"; b.textContent = "copy";
    b.onclick = async () => { await navigator.clipboard.writeText(pre.innerText); b.textContent = "copied"; setTimeout(() => b.textContent = "copy", 1200); };
    pre.appendChild(b);
  });

  // Filter: hide non-matching <li> and sections with no matches.
  const filter = document.getElementById("filter");
  filter.addEventListener("input", () => {
    const q = filter.value.trim().toLowerCase();
    document.querySelectorAll("article section").forEach(sec => {
      if (!q) { sec.classList.remove("hidden"); sec.querySelectorAll("li,.card").forEach(el => el.classList.remove("hidden")); return; }
      let anyVisible = false;
      sec.querySelectorAll("li,.card").forEach(el => {
        const hit = el.textContent.toLowerCase().includes(q);
        el.classList.toggle("hidden", !hit);
        if (hit) anyVisible = true;
      });
      const headerHit = sec.querySelector("h2").textContent.toLowerCase().includes(q);
      sec.classList.toggle("hidden", !anyVisible && !headerHit);
    });
  });

  // Active TOC highlight on scroll.
  const links = [...toc.querySelectorAll("a")];
  const io = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (!e.isIntersecting) return;
      links.forEach(l => l.classList.toggle("active", l.getAttribute("href") === "#" + e.target.id));
    });
  }, { rootMargin: "-40% 0px -55% 0px" });
  document.querySelectorAll("article section").forEach(s => io.observe(s));
</script>

</body>
</html>
```

## Rules of engagement

- **One file only.** No sibling CSS/JS. Mermaid comes from the CDN with a fallback; everything else is inline.
- **Cite paths.** Use `path/to/file.ext:line` inside `<span class="path">…</span>`. Every non-trivial claim in Data model / API / Frontend should carry at least one citation.
- **Don't rewrite code.** This is a read-only report.
- **Don't fabricate.** If the session doesn't cover something, either omit the section or mark it clearly in Open questions as "not verified".
- **Keep the title honest.** `{{TITLE}}` should be the actual topic — not "Summary of this session".
- **Be terse.** Dense bullets beat paragraphs. The HTML should be useful at a glance.
- **Reply small.** After writing, respond in chat with just: the file path, a one-line gist, and anything that was ambiguous. Do not paste the HTML back.
