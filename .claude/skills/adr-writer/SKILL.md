---
name: adr-writer
description: Write a new Architecture Decision Record into docs/adr/yyyyMMdd.md following this project's format and language (Japanese). Use this whenever the user asks to record a design or architecture decision, document why something was built a certain way, summarize a completed step of a multi-step plan for later reference, or says things like "ADRにまとめて", "decision recordを書いて", "設計判断を記録して", "docsにまとめておきたい" about technical work just done. Trigger even when the user doesn't say "ADR" explicitly, as long as they want a durable, dated record of a decision and its reasoning — not just a chat summary.
---

# Writing an ADR for this project

This repo records architecture/design decisions as dated Markdown files in
`docs/adr/`, written in Japanese (matching the rest of this repo's
documentation, e.g. `AGENTS.md`, `README.md`). An ADR here isn't a meeting
minutes log — its job is to let a future reader (human or agent) understand
*why* something was built a particular way without having to reconstruct the
conversation that led there.

## File naming

`docs/adr/yyyyMMdd.md`, using the current date. If more than one ADR is
written on the same day, disambiguate with a numeric suffix:
`docs/adr/20260920-2.md`.

## Required sections

Use this exact structure (Japanese headings/body, English section labels are
fine to keep, as the existing ADRs do):

```markdown
# ADR yyyy-MM-dd: <一言でわかるタイトル>

## Status

Accepted   <!-- or: Proposed / Superseded by ADR-... -->

## Context

<なぜこの決定が必要だったか。背景、制約、検討した選択肢があれば触れる。>

## Decision

<何を決めたか。ディレクトリ構成やファイル名など、具体的な内容を書く。>

## Consequences

<この決定によって次に何ができるようになるか、何が制約になるか。
未解決の課題やフォローアップがあれば明記する。>
```

## What makes a good entry here (not just a status update)

- **Link, don't restate.** Reference the actual files this decision touches
  with relative Markdown links (e.g. `[grpc/main.go](../../grpc/main.go)`)
  rather than pasting large code blocks.
- **Include verification, not just intent.** If a command was run to confirm
  the decision actually works (a build, a `grpcurl` call, a test), paste the
  real command and its real output — this is what separates an ADR from a
  plan. Never fabricate output; only include what was actually observed in
  this session.
- **State the "why now" / sequencing.** If this decision is one step in a
  larger plan (see this repo's `AGENTS.md` roadmap), say which step it is and
  what depends on it next — that context is exactly what's hardest to
  reconstruct later.
- **Keep Consequences honest.** Note real limitations (e.g. "no TLS, local
  dev only") rather than only upside — that's what makes the record useful
  when someone later hits that limitation.

## After writing

Check whether `AGENTS.md` (or `CLAUDE.md`) should link the new ADR — this
repo's `AGENTS.md` keeps a short roadmap with links into `docs/adr/`, so a
new ADR that changes project status should usually be cross-linked from
there too, not left orphaned.
