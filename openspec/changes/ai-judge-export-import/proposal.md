## Why

AI judge identity is lost during book and case export/import. Judgements reference users by `user_email`, but AI judges often lack a meaningful email — they're identified by `name`. When importing a book with AI-judge-authored judgements on a different instance, `force_create_users` creates regular stub users via `User.invite!`, losing the judge's configuration (system_prompt, judge_options) and the distinction between human and AI judges. Additionally, the API import endpoint (`POST /api/import/books`) doesn't expose `force_create_users` at all, blocking SDK-driven migrations.

## What Changes

- **Book export** includes a top-level `ai_judges` array with each judge's name, system_prompt, and judge_options (excluding `llm_key` — it's a secret).
- **Book export** judgements include `judge_name` for AI-judge-authored judgements (alongside existing `user_email` for human users).
- **Book import** (`BookImporter`) matches AI judges by `name`: if found, reuses; if missing and `force_create_users` is true, creates the AI judge with exported config and a visible placeholder `llm_key`.
- **Case import** (`CaseImporter`) supports `force_create_users` for human users and applies name-based AI judge matching for ratings (when `user_id` is present on ratings).
- **API book import endpoint** (`POST /api/import/books`) exposes the `force_create_users` parameter.
- **API case import endpoint** (`POST /api/import/cases`) exposes the `force_create_users` parameter.
- Validation runs first for AI judges (fail early before processing query_doc_pairs/queries).

**Not changed (case export):** Case export is NOT modified for AI judges. Cases store aggregated ratings via `RatingsManager`, not per-judge ratings. When book judgements are synced to a case, multiple judgements are combined into a single `Rating` record with no `user_id`. Individual judge identity is preserved only in Books. See design.md for details on the aggregation algorithm.

## Capabilities

### New Capabilities
- `ai-judge-serialization`: Export and import of AI judge definitions and their judgement attribution in books and cases. Covers name-based matching, config round-tripping (minus secrets), and placeholder key creation.

### Modified Capabilities
<!-- None. The ai-judge-serialization capability is self-contained. judge_options is a provider-agnostic JSON blob that works for all LLM providers (OpenAI, Azure, Anthropic, Gemini, Ollama). -->

- **Case export** omits `custom_headers` and `basic_auth_credential` from search endpoint serialization to avoid leaking secrets (API keys, auth tokens). Same principle as `llm_key` on AI judges. On import, the search endpoint is created without credentials — searches return 401 until the user configures credentials on the target instance.

## Impact

- `app/views/api/v1/export/books/_book.json.jbuilder` — add `ai_judges` array
- `app/views/api/v1/export/books/_judgements.json.jbuilder` — add `judge_name`
- `app/views/api/v1/search_endpoints/_search_endpoint.json.jbuilder` — omit `custom_headers` and `basic_auth_credential` in export mode
- `app/services/book_importer.rb` — AI judge matching by name, creation with placeholder key
- `app/services/case_importer.rb` — `force_create_users` for human users
- `app/controllers/api/v1/import/books_controller.rb` — expose `force_create_users`
- `app/controllers/api/v1/import/cases_controller.rb` — expose `force_create_users`
- Test files for all modified controllers and services
