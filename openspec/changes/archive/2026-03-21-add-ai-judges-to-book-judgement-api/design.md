## Context

The Python SDK workspace export flow uses the regular book and judgement API endpoints (not the export endpoints) to fetch data. The export endpoints (`PUT /api/export/books/:id`) already include AI judge data, but they are async and return a download URL — unsuitable for the SDK's direct-fetch workflow.

The export jbuilder partials already have the exact patterns needed. This change mirrors them into the regular API partials.

## Goals / Non-Goals

**Goals:**
- Book API responses include `ai_judges` array with name, system_prompt, judge_options
- Judgement API responses include `judge_name` (AI) and `user_email` (human) fields
- No N+1 queries from the new associations

**Non-Goals:**
- Changing the export endpoints (already done)
- Adding `llm_key` to any response (secret, never exposed)
- Modifying the import flow (separate task)

## Decisions

**1. Add ai_judges to shared `_book` partial (not conditionally)**
Rationale: User confirmed all book endpoints should include ai_judges. Simpler than conditional rendering.

**2. Mirror export partial patterns exactly**
Rationale: The export partials (`_judgements.json.jbuilder`, `_book.json.jbuilder`) already define the correct field set. Using the same pattern ensures consistency between export and regular API.

**3. Eager-load at controller level**
Rationale: Adding `includes(:ai_judges)` and `includes(:user)` prevents N+1 queries. Standard Rails pattern.

## Risks / Trade-offs

- [Slightly larger API responses] → Minimal: ai_judges is typically 0-3 records per book. Acceptable for consistency.
- [Breaking change for API consumers expecting smaller payloads] → Additive only (new fields), no fields removed. Non-breaking.
