## Project Conventions

- This project uses a BMAD story pipeline workflow with skills (bmad-create-story, bmad-dev-story, bmad-testarch-trace). Always follow the 5-step pipeline: story creation → ATDD tests → development → code review → coverage trace.
- When writing E2E tests, use the real environment (not mocks). Do not create mock-based tests for E2E test files.

## Testing Rules

- Always run the full test suite after making changes and report the total count (e.g., 'all 882 tests passing').
- When generating E2E tests for LLM-driven tool calls, use single-action prompts only — never ask the LLM to perform two actions in one call, as this causes unreliable behavior.
- After code review fixes, always re-run the full test suite to verify no regressions.
- When fixing bugs found in one code path (e.g., insert mode), check all sibling code paths (e.g., replace, delete) for the same issue.

## Swift / TypeScript Conventions

- In Swift files, avoid naming types `Task` — it conflicts with Swift Concurrency's `Task`. Use a project-specific prefix or alternative name.
- When SourceKit reports large numbers of compilation errors after code generation, verify via an actual build (`swift build` or `xcodebuild`) before attempting fixes — stale diagnostics are common.
- For TypeScript, ensure all new types follow existing naming patterns and don't create conflicts with built-in types.

## Edit Discipline

- When editing template files (FTL, HTML, SCSS), read the full file first and plan edits carefully. Do not make partial edits that truncate content or add non-existent references.
- If an Edit tool call fails due to whitespace matching, do a full file rewrite with Write rather than retrying the same Edit.
- Never get stuck in a loop of repeated edits to the same file — if an edit doesn't work after 2 attempts, step back, re-read the file, and write the complete corrected version.