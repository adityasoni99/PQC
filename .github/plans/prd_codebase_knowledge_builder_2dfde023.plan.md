---
name: PRD Codebase Knowledge Builder
overview: Produce a structured Product Requirements Document (PRD) for the AI-powered Codebase Knowledge Builder, grounded in [docs/design.md](docs/design.md), with full product scope, all target users, CLI-first delivery (API/UI post-MVP), and success defined by output quality.
todos: []
isProject: false
---

# PRD for AI-Powered Codebase Knowledge Builder

## Source of truth

The PRD will be derived from [docs/design.md](docs/design.md), which already defines:

- **Requirements**: User story, inputs (GitHub URL or local path, optional project name and language), outputs (project directory with `index.md` and chapter Markdown files).
- **Flow**: Workflow + Batch pattern — FetchRepo → IdentifyAbstractions → AnalyzeRelationships → OrderChapters → WriteChapters (BatchNode) → CombineTutorial.
- **Utilities**: `crawl_github_files`, `crawl_local_files`, `call_llm`.
- **Shared store**: Inputs (repo_url, local_dir, project_name, language, etc.) and intermediate/outputs (files, abstractions, relationships, chapter_order, chapters, final_output_dir).
- **Node design**: Six nodes with prep/exec/post (and batch behavior for WriteChapters), including i18n (translated names/descriptions/summary/labels/chapters when language ≠ English).

No code will be written; only the PRD markdown file will be produced.

---

## PRD structure and content (per PRD skill)

### 1. Overview

- **Product**: AI-powered Codebase Knowledge Builder that turns a GitHub repo or local directory into a structured, beginner-friendly tutorial (project summary, Mermaid relationship diagram, ordered chapters).
- **Problem**: Developers and technical writers spend hours manually exploring a codebase to understand core abstractions and their relationships.
- **Why now**: LLMs and structured workflows (e.g. PocketFlow) make automated analysis and tutorial generation feasible and maintainable.

### 2. Goals and non-goals

- **Goals**: (1) Generate accurate, readable tutorials that explain core abstractions and relationships; (2) Support GitHub and local inputs; (3) Optional language for translated output; (4) Deterministic, testable pipeline (Workflow + Batch).
- **Non-goals**: Real-time IDE integration, editing of existing docs, authentication/SSO, multi-repo comparison, and non-tutorial artifacts (e.g. API reference) in MVP/post-MVP as explicit exclusions.

### 3. Target users

- **Personas**: New developers onboarding; any developer exploring an unfamiliar repo; technical writers or docs maintainers.
- **Technical level**: Medium to high (comfort with CLI, env vars, optional GitHub token).
- **Pain points**: Time spent digging through code, unclear structure, missing high-level narrative and relationship visualization.

### 4. MVP scope

- **In scope (MVP)**: CLI entrypoint; inputs = GitHub URL or local path, optional project name and language; full pipeline per design (FetchRepo → … → CombineTutorial); output = directory with `index.md` (summary, Mermaid, chapter links) and `01_*.md` … `0N_*.md`; utilities `crawl_github_files`, `crawl_local_files`, `call_llm`; shared store and node behavior as in design; English + one non-English language for translation.
- **Out of scope (post-MVP)**: API, UI, incremental/partial runs, custom templates, pluggable LLM backends (beyond one configured provider), and advanced quality controls (e.g. self-evaluation node).

Grouped by: Core functionality (pipeline, I/O, translation); Technical (PocketFlow, shared store, utilities); Integrations (GitHub API, local FS, single LLM provider).

### 5. User stories

- **US-001** – Generate tutorial from GitHub URL (As a developer I want to pass a repo URL and get a tutorial directory so that I can onboard quickly). Acceptance: CLI accepts `--repo-url`, run produces `index.md` + chapters under a project-named dir; content is readable and references abstractions.
- **US-002** – Generate tutorial from local directory (As a developer I want to pass a local path and get a tutorial so that I can document private or offline code). Acceptance: CLI accepts `--local-dir`, output structure same as US-001.
- **US-003** – Optional project name and language (As a user I want to set project name and tutorial language so that output is named and localized). Acceptance: Optional args/env; when language is set, summary/names/descriptions/chapters follow design’s translation behavior.
- **US-004** – Readable relationship diagram (As a user I want a Mermaid diagram in `index.md` so that I see how abstractions connect). Acceptance: `index.md` contains valid Mermaid (flowchart) with nodes and edges from `relationships.details`; labels/names respect language.

Stories will be small and verifiable; UI-related stories N/A for MVP (CLI-only).

### 6. Functional requirements

- **FR-1**: System shall accept either a GitHub repository URL or a local directory path as input.
- **FR-2**: System shall produce an output directory containing `index.md` and one Markdown file per chapter, ordered by `chapter_order`.
- **FR-3**: `index.md` shall include a high-level project summary, a Mermaid flowchart of abstraction relationships, and an ordered list of links to chapter files.
- **FR-4**: Each chapter shall describe one core abstraction in beginner-friendly language and reference relevant code (e.g. by file index or path).
- **FR-5**: When a non-English language is specified, names, descriptions, summary, relationship labels, and chapter content shall be generated in that language per design.
- **FR-6**: System shall support configurable file inclusion/exclusion and max file size for crawl (per design).
- **FR-7**: Pipeline shall follow the node sequence in design (FetchRepo → IdentifyAbstractions → AnalyzeRelationships → OrderChapters → WriteChapters → CombineTutorial) with shared store as the contract.

Numbered and testable; no low-level implementation mandated.

### 7. Design and UX considerations

- CLI: clear help, required vs optional args, exit codes (0 success, non-zero failure), and where output is written (e.g. `--output-dir` default).
- Accessibility: N/A for CLI-only MVP; if a future UI is added, document expectations then.
- Reuse: PocketFlow Node/Flow/BatchNode; existing utilities and shared store schema from design.

### 8. Technical considerations

- **Constraints**: Single LLM provider per run; GitHub rate limits when no token or with token; local disk and memory for file contents and LLM context.
- **Dependencies**: requests (and optionally GitPython for GitHub), LLM API client (e.g. Google GenAI), PocketFlow; YAML for structured LLM output.
- **Performance**: BatchNode for chapters to avoid monolithic prompt; consider token limits when building context (design’s `create_llm_context` / `get_content_for_indices`); max file size and filtering to keep crawls bounded.

### 9. Success criteria

- **Done** for v1: (1) All MVP scope items implemented and passing acceptance criteria; (2) Output quality: generated tutorial is readable, abstractions and relationships are accurate and logically ordered; (3) Pipeline runs end-to-end for at least one public GitHub repo and one local directory; (4) Optional language produces coherent translated output.
- Measurable where possible: e.g. “run completes without error for repo X” and “human review: summary and chapter order make sense.”

### 10. Implementation phases (high-level)

- **Phase 1 – Foundation**: Shared store schema, FetchRepo (crawl_github + crawl_local), CLI skeleton (args, output dir). Deliverables: utilities, FetchRepo node, minimal flow that writes `files` and `project_name`.
- **Phase 2 – Analysis**: IdentifyAbstractions, AnalyzeRelationships, OrderChapters; wire into flow; validate YAML and indices. Deliverables: three nodes, shared store populated through `chapter_order`.
- **Phase 3 – Content**: WriteChapters (BatchNode), CombineTutorial; Mermaid generation; write `index.md` and chapter files. Deliverables: full pipeline, end-to-end output directory.
- **Phase 4 – Polish**: Language option end-to-end, error handling and logging, docs and README, basic manual quality checks. Deliverables: MVP complete; post-MVP (API/UI) listed as open.

### 11. Risks and mitigations

- **LLM hallucination or wrong indices**: Mitigation — structured prompts, YAML output, validation of indices against `files`/`abstractions` and retries/fallbacks per Node design.
- **Large repos / context limits**: Mitigation — max file size, include/exclude patterns, and context-building helpers that trim or summarize content.
- **GitHub rate limits or private repos**: Mitigation — document token usage; support local_dir as primary path for sensitive code.
- **Output quality variance**: Mitigation — clear prompts, examples in prompts where helpful, and human review as part of success criteria until automated checks exist.

### 12. Open questions

- Exact CLI interface (e.g. `--repo-url` vs `repo_url` positional) and env var names.
- Default and supported values for `language` (e.g. ISO codes).
- Post-MVP: API contract (sync vs async, webhooks), UI scope (upload vs link, view-only vs edit).

---

## Output

- **Format**: Markdown.
- **Path**: [docs/prd-codebase-knowledge-builder.md](docs/prd-codebase-knowledge-builder.md) (co-located with [docs/design.md](docs/design.md); no `tasks/` folder exists).
- **Naming**: `prd-codebase-knowledge-builder.md` (kebab-case).
- Assumptions will be labeled in the PRD where inputs (e.g. exact CLI flags) are TBD.

---

## Summary

The PRD will be written in one markdown file following the 12 sections above, with checkboxes for MVP scope and deliverables, and will reference the design doc for flow, nodes, utilities, and shared store so implementation stays aligned with the existing design.
