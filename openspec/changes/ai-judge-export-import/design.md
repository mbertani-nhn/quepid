## Context

Quepid's book/case export emits `user_email` for judgement/rating attribution. AI judges are `User` records with `llm_key IS NOT NULL`, identified by `name` (email validation is skipped for them). The `BookImporter` and `CaseImporter` both match users by email and optionally create missing users via `User.invite!` — which creates regular users, not AI judges.

The SDK workspace export/import (`quepid-sdk/_workspace.py`) strips all IDs and uses name-based matching for scorers and search endpoints. AI judge support was deferred as a follow-up (design.md: "AI judge configuration export — planned follow-up").

The `books_ai_judges` join table (HABTM) associates AI judges with books. This relationship is not currently exported.

## Goals / Non-Goals

**Goals:**
- AI judges survive book round-trips with config intact (system_prompt, judge_options)
- AI judges matched by name on import — no duplicates on repeated imports
- `llm_key` never exported (secret), placeholder created for new judges
- `force_create_users` exposed on both API import endpoints (books + cases)
- Validation fails early if AI judges or users are missing and `force_create_users` is false
- Exported format is backward-compatible (old importers ignore new fields)

**Non-Goals:**
- SDK changes (separate follow-up using this spec as input)
- Exporting `llm_key` or any other secrets
- Merging/overwriting existing AI judge configs on import
- UI changes to the book/case import forms (they already have `force_create_users`)
- Case export changes for AI judges (see Decision 8 below)

## Decisions

### 1. Match AI judges by `name`, not email

AI judges skip email validation and often don't have one. Name is the natural identifier, consistent with how scorers are matched (`Scorer.find_by(name:)`). On import: if `User.only_ai_judges.find_by(name:)` returns a match, reuse it.

**Alternative considered:** Match by email — rejected because AI judges may not have emails, and email-based matching already exists for human users.

### 2. Export AI judges as top-level `ai_judges` array in book JSON

```json
{
  "name": "Book of Ratings",
  "ai_judges": [
    {
      "name": "Azure OpenAI Judge",
      "system_prompt": "You are evaluating...",
      "judge_options": {
        "llm_provider": "azure_openai",
        "llm_service_url": "https://myresource.openai.azure.com",
        "llm_model": "gpt-4.1",
        "llm_timeout": 30,
        "llm_api_version": "2024-12-01-preview"
      }
    }
  ],
  "query_doc_pairs": [...]
}
```

The `ai_judges` array is derived from `book.ai_judges` (the HABTM association). This avoids repeating config per judgement and clearly separates judge definitions from judgement data.

### 3. Add `judge_name` to judgement export (books only)

```json
{
  "rating": 2.0,
  "user_email": null,
  "judge_name": "Azure OpenAI Judge",
  "explanation": "Relevant result"
}
```

The importer resolves `judge_name` first (AI judge by name), then falls back to `user_email` (human user by email). This is backward-compatible: old exports without `judge_name` continue to work via email.

**Not applied to case ratings** — see Decision 8.

### 4. Placeholder `llm_key` for newly created AI judges

When `force_create_users` creates an AI judge, it uses `llm_key: "REPLACE_ME"`. This:
- Satisfies the `validates :llm_key, presence: true` constraint
- Is clearly visible in the UI as needing attention
- Prevents the judge from producing real judgements until configured

### 5. Validation order: AI judges first, then human users

The importer validate method processes in order:
1. Collect unique `judge_name` values from judgements → check/create AI judges
2. Collect unique `user_email` values from judgements (where `judge_name` is blank) → check/create human users

This fails early on missing judges before processing the potentially large QDP list.

### 6. API endpoints expose `force_create_users` as top-level param

Both `POST /api/import/books` and `POST /api/import/cases` accept `force_create_users` as a top-level boolean parameter (alongside `team_id`), matching the pattern used by the UI import controllers. Deserialized via the existing `deserialize_bool_param` helper.

### 7. Book import also associates AI judges with the imported book

When an AI judge is referenced in the imported book (either found by name or newly created), it is added to `book.ai_judges` via the HABTM association. This restores the `books_ai_judges` relationship.

### 8. Case export NOT modified for AI judges

Cases store **aggregated** ratings, not per-judge ratings. When book judgements are synced to a case via `RatingsManager.sync_judgements_to_ratings`, multiple judgements are combined into a single `Rating` record with **no `user_id`**:

```
  BOOK (per-judge detail)              CASE (aggregated)
  ┌──────────────────────┐             ┌──────────────────┐
  │ QueryDocPair         │             │ Query            │
  │   Judgement (judge A)│──┐          │   Rating         │
  │   Judgement (judge B)│──┼─ sync ──▶│     doc_id       │
  │   Judgement (human)  │──┘          │     rating: 2.0  │
  └──────────────────────┘  aggregate  │     user_id: nil │
                                       └──────────────────┘
```

Because of this, adding `ai_judges` or `judge_name` to case export would always produce empty values. Individual judge identity is preserved only in Books. Use the book export for per-judge detail and the case export for aggregated results with query groupings and search endpoint config.

**Note on human ratings in cases:** Even when a human rates directly in the case UI (via `queries/ratings_controller.rb`), the `Rating` record is created without `user_id` (`Rating.find_or_create_by(query: query, doc_id: doc_id)`). So case ratings are architecturally anonymous regardless of who created them. This is a pre-existing design choice, not something introduced by this change.

The case import side (`CaseImporter`) is kept: it supports `force_create_users` for human users (useful when importing cases between instances), and the AI judge matching code is retained for forward-compatibility should case ratings gain `user_id` in the future.

### 9. Aggregation algorithm — how book judgements become case ratings

`RatingsManager.calculate_rating_from_judgements` uses an optimistic-pessimistic approach to combine multiple judge ratings into a single case rating:

1. **1-2 judgements:** Average them (not enough data for consensus)
2. **3+ judgements:** Take the three highest ratings (optimistic: assume the best judges rated highest). If all three agree, use that value. If they disagree, use the minimum of the top three (pessimistic: trust the lower rating, assuming judges tend to overrate).

This means no single judge "wins" — the aggregation considers all rateable judgements from both human and AI judges. The per-judge detail (including explanations) lives only in the Book.

### 10. Search endpoint credentials omitted from export

The `_search_endpoint.json.jbuilder` partial is shared between normal API responses and export. In export mode (`export: true`), `custom_headers` and `basic_auth_credential` are now omitted. These fields contain secrets (API keys, auth tokens) that should not be serialized into shareable JSON — the same principle as omitting `llm_key` from AI judge exports.

**Impact on import:** The `CaseImporter` uses the exported `search_endpoint` hash for two purposes:

1. **Matching** (`find_by`): Omitting credential fields actually improves matching — it finds endpoints by `name + endpoint_url + search_engine + api_method` without requiring credentials to match too. A user who already has the endpoint configured with their own credentials will match correctly.

2. **Creation** (`SearchEndpoint.new`): If no match is found, a new endpoint is created without credentials. Both `custom_headers` (`allow_blank: true`) and `basic_auth_credential` (no validation) accept nil. Searches will return 401 until the user configures credentials on the target instance — consistent with how AI judges need `llm_key` configured after import.

**No impact on normal API responses**: The `export` flag is only set to `true` by the export controllers. Normal API responses (used by the frontend) continue to include `custom_headers` and `basic_auth_credential`.

## Risks / Trade-offs

- **[Name collisions]** → Two AI judges with the same name but different configs on different instances. Mitigation: import reuses the existing judge without overwriting — the admin's local config wins. Documented behavior.
- **[Placeholder key]** → Newly created AI judges can't produce judgements until `llm_key` is updated. Mitigation: the placeholder `REPLACE_ME` is intentionally obvious. The judge will fail with an auth error if accidentally used.
- **[Backward compatibility]** → Old exports without `ai_judges` or `judge_name` fields. Mitigation: importer treats missing fields as nil, falls back to email-only matching (current behavior).
- **[Large AI judge configs]** → `judge_options` is a JSON blob that could grow. Mitigation: currently small (5 keys); if it grows, it's still per-judge not per-judgement.
- **[Imported endpoints missing credentials]** → Searches fail with 401 until credentials are configured on the target instance. Mitigation: credentials are instance-specific anyway (different API keys per environment). The user must configure them after import, same as `llm_key` on AI judges.
