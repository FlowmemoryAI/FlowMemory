# Start Here

This is the first document to read after `AGENTS.md`.

## Reading Order

1. `AGENTS.md`
2. `docs/FLOWMEMORY_HQ_CONTEXT.md`
3. `docs/CURRENT_STATE.md`
4. The task-specific document or issue
5. Any relevant decision records in `docs/DECISIONS/`

## Before You Edit

- Confirm the assigned scope.
- Check the current branch and working tree.
- Read the files you plan to edit.
- Identify whether the task is docs, protocol, service, app, hardware, research, crypto, infra, or security work.
- If the task touches architecture, security assumptions, public schemas, or cross-agent workflow, update docs in the same pull request.

## During Work

- Keep changes small and reviewable.
- Do not edit unrelated files.
- Do not hardcode secrets.
- Add tests where practical.
- Document open questions instead of silently inventing protocol facts.
- Prefer explicit boundaries over vague claims.

## Before You Finish

Run the checks that exist for the area you touched. If no test suite exists yet, say that clearly.

End with a PR-ready summary:

- What changed
- Why it changed
- Tests or checks run
- Risks, assumptions, and follow-ups
