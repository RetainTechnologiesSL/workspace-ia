---
name: enrich-us-easy
description: Analyze and enhance user stories with complete, implementation-ready technical detail from direct ticket input or an EasyRedmine issue.
version: 1.0.0
---
# enrich-us-easy Skill

Use it when the ticket to enrich lives in EasyRedmine instead of Jira. Same enrichment process as `enrich-us`, but the fetch/write-back step talks to EasyRedmine's REST API directly (no MCP), via `scripts/easy-redmine.sh`.

## Setup

Requires `EASY_REDMINE_URL` and `EASY_REDMINE_API_KEY` in the environment (same variables already used by `projects/devx/gestor/.env`, e.g. `EASY_REDMINE_URL=https://easyredmine.retain.es`). The personal API key is in EasyRedmine under "My account" > "API access key". `jq` and `curl` must be available.

To resolve which workspace repo/folder an issue belongs to, also set `DEVX_API_URL` (devx/gestor base URL) and `DEVX_PROYECTOS_API_KEY` (static API key matching devx's own `DEVX_PROYECTOS_API_KEY` env var, sent as `X-Api-Key`).

## Instructions

Please analyze and enrich the ticket: $ARGUMENTS.

Follow these steps:

1. Determine the ticket input source:
   - **Direct input mode (default when ticket text is provided):** Use the ticket content shared by the user in the prompt/chat.
   - **EasyRedmine mode (optional):** If the user provides an EasyRedmine issue id/number, or asks to use EasyRedmine/Easy (including references like "the one in progress"), fetch it with:
     ```
     ai-specs/skills/enrich-us-easy/scripts/easy-redmine.sh get <issue_id>
     ```
     Use the returned `subject` as title and `description` as the original ticket body. Treat journal entries (`journals[].notes`) as extra context, not as part of the original description.
2. **Resolve which repo/folder to work on (EasyRedmine mode only).** Take `project.id` from the fetched issue and resolve it to a workspace repo with:
   ```
   ai-specs/skills/enrich-us-easy/scripts/resolve-project.sh <project_id>
   ```
   This calls devx's `GET /api/proyectos/by-easyredmine/{idEasyRedmine}` (see `projects/devx/gestor/src/Controller/Api/ProyectoApiController.php`), which returns `repositorio`/`repositorioGithub` for the matching `Proyecto`. Match the last path segment of that repo slug against a folder under `projects/` in this workspace (for example `repositorioGithub: RetainTechnologiesSL/easy-redmine-retain` → `projects/easy-redmine-retain`).
   - If the script returns 404, no `Proyecto` in devx has that `idEasyRedmine` registered — tell the user and ask which repo/folder to use instead of guessing.
   - If the resolved slug does not match any folder under `projects/`, say so explicitly and ask the user; do not assume a close-enough name.
   - In direct input mode, skip this step: the user is already in the right project/folder when invoking the skill.
3. **Already-enriched check (before any analysis):** Determine whether the ticket was already enriched by this skill. A ticket counts as already enriched when its content contains both an `[original]` and an `[enhanced]` section (EasyRedmine write-back format, `h2` headings), or both `## Original` and `## Enhanced` headings (direct input mode), and the `[enhanced]`/`## Enhanced` section is non-empty.
   - If already enriched: **skip the whole process**. Do not re-analyze, do not rewrite the enhanced content, do not update EasyRedmine. Report it explicitly, for example: `Skipped: issue <id or title> is already enriched (found [original] and [enhanced] sections). No changes made.` Then stop.
   - Re-enrichment only happens if the user explicitly asks for it (for example "re-enrich", "enrich again", "force"). In that case, replace the existing `[enhanced]` section instead of appending a second one.
4. Act as a product expert with technical knowledge.
5. Understand the problem described in the ticket.
6. Decide whether or not the User Story is completely detailed according to product best practices. Validate that it includes:
   - Full functionality description
   - Comprehensive list of fields to update
   - Required endpoints structure and URLs
   - Files/modules to modify according to architecture and best practices
   - Definition of done (implementation and delivery steps)
   - Documentation and unit test updates
   - Non-functional requirements (security, performance, observability, etc.)
   - E2E test cases, when the story changes frontend behavior (see step 7a)
7. If the story lacks enough technical detail for autonomous implementation, provide an improved version that is clearer, more specific, and concise, aligned with step 6. Use project technical context from `@documentation`. Return the result in markdown.
7a. **E2E test cases (only when the story changes frontend behavior).** Pure backend, API-only, job, migration or harness stories skip this step and say `E2E test cases: N/A (no frontend behavior)` in `## Enhanced`.
   - Load and follow the `playwright-qa-scenarios` skill in **catalog mode** (`ai-specs/skills/playwright-qa-scenarios/SKILL.md`), with the story (and the draft enhanced content) as input.
   - Add the result to `## Enhanced` as a `### E2E test cases (Playwright)` section. Do **not** create a separate file and do **not** write Playwright code here.
8. Output format (when not skipped) must always include:
   - `## Original`
   - `## Enhanced` (including `### E2E test cases (Playwright)` when step 7a applies)
   - **Required deliverable, not only a chat response:** write this `## Original` / `## Enhanced` output to `tmp/enriched-us/<change-name>.md` (or `tmp/enriched-us/easy-<issue_id>.md` in EasyRedmine mode, when no change name exists yet). Create the `tmp/enriched-us/` directory if it does not exist.
9. EasyRedmine write-back is optional and only applies in EasyRedmine mode:
   - Build the full enhanced description text, with clear `h2`/markup sections `[original]` and `[enhanced]` and readable formatting (lists/code snippets when useful), written to a temp file.
   - Update the issue's description with:
     ```
     ai-specs/skills/enrich-us-easy/scripts/easy-redmine.sh update-description <issue_id> <temp-file>
     ```
   - EasyRedmine has no direct "move to status X" ticket name matching Jira's `Pending refinement validation`; if the project defines an equivalent status id (check `EASY_REDMINE_STATUS_*` env vars or ask the user), update it via a direct PUT with `{"issue": {"status_id": <id>}}` through the same script pattern, otherwise skip the status change and say so.

## Notes

- Do not require EasyRedmine when the user already provided full ticket content directly.
- If input is ambiguous (for example, user gives a short reference without content), ask whether to resolve via EasyRedmine or request the full ticket text.
- The script reuses the exact base URL / header pattern (`X-Redmine-API-Key`) already implemented in `projects/devx/gestor/src/Service/EasyRedmineService.php`; if that service ever changes its auth scheme or base URL handling, mirror the change here.
