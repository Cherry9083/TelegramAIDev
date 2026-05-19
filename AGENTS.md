# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## 5. Mission

This repo exists to improve `CJMP` AI-assisted development efficiency, with the goal of outperforming typical `KMP` workflows for building a Telegram-like commercial application.
The project should keep comparing those approaches on comparable slices, expose where `CJMP` falls short for AI-assisted delivery, and continuously improve the AI engineering layer around `CJMP`.

## 6.Constraints

- A valid evaluation of AI-assisted development efficiency requires a professional product bar and a user experience close to Telegram for common flows.
- Do not let implementation cost explode.
- Do not plan features or functions unless they help expose, compare, or solve meaningful AI-efficiency problems.
- Do not over-polish beyond what is needed to support a credible Telegram-like commercial demo.

### Non-artifact Locations

- `docs`: Development process artifacts, requirements->acceptance/design

### Shared Invariants

- Use GitHub issues to drive the project.
- Keep framework-agnostic product and UI designs separate from framework specific implementation details.

### 7. Cangjie-related content 

- Support application developers using CJMP.
- When Cangjie syntax documentation is needed, use `cangjie-lang-features`, `cangjie-original-docs`, `cangjie-regulations`, `cangjie-std`, `cangjie-stdx` skills to retrive related contents.
- When CJ-UI-related content is needed, use Context7 to retrieve documentation from the `walter-MITTY-PRO/cangjie-corpus` repository.
- Cangjie toolchain, such as cjc，cjpm, should be used after run `source $CJMP_SDK_HOME/cjmp-tools/third_party/cangjie-android/envsetup.sh` when you build android apps, or run `source $CJMP_SDK_HOME/cjmp-tools/third_party/cangjie-ios/envsetup.sh` when build ios apps.
- When CJMP-related context is needed, 