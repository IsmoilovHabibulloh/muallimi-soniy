---
trigger: always_on
---

# Beads Context & Workflow Protocols

You are strictly required to use the `bd` (Beads) tool for all task management.
Follow these protocols without exception.

## 1. Issue Creation Guidelines
**Constraint:** NEVER create a vague issue.
When running `bd create`, the description MUST include these 3 sections:
1.  **Acceptance Criteria:** Clear, testable conditions (definition of done).
2.  **Steps to Solve:** A detailed, step-by-step breakdown of the implementation.
3.  **File List to Review:** Specific files that need to be examined or modified.

## 2. Task Completion Protocol (CRITICAL)
**WARNING:** NEVER auto-close issues. NEVER commit without explicit confirmation.

**Algorithm for finishing a task:**
1.  **Self-Correction:** Verify the work against the "Acceptance Criteria".
2.  **Stop & Ask:** Say exactly: *"Task completed. Should I close issue #<id>?"*
3.  **WAIT:** Do not proceed until the user says "Yes", "Close it", or "Proceed".
4.  **Action:** Only AFTER confirmation, run `bd close <id>`.
5.  **Commit Check:** Provide a summary of changes and ask: *"Ready to commit?"*
6.  **Commit:** Once confirmed, write a comprehensive commit message and commit.

## 3. Landing the Plane (Session Completion)
**Trigger:** When the user says "finish session", "wrap up", or stops working.
**Rule:** Work is NOT complete until `git push` succeeds. NEVER leave work stranded locally.

**Mandatory Workflow:**
1.  **File Remaining Work:** Run `bd create` for any loose ends or follow-ups.
2.  **Quality Gates:** Check code syntax, run tests if available.
3.  **Update Status:** Ensure all finished work is `bd close`'d.
4.  **PUSH SEQUENCE (Execute Exactly):**
    ```bash
    git pull --rebase
    bd sync
    git push
    git status  # Must show "up to date with origin"
    ```
5.  **Hand Off:** Provide a short context summary for the next session.

## Core Philosophy
* **Source of Truth:** `bd` is your memory.
* **No Assumptions:** Never assume the user wants to close/commit. ASK.
* **Sync:** If it's not on the remote repo, it doesn't exist.