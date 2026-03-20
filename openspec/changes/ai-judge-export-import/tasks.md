## 1. Export changes

- [x] 1.1 Add `ai_judges` array to book export (`_book.json.jbuilder`) with name, system_prompt, judge_options
- [x] 1.2 Add `judge_name` to judgement export (`_judgements.json.jbuilder`) for AI-judge-authored judgements
- [x] 1.3 **REVERT case export**: Revert `_case.json.jbuilder` and `_rating.json.jbuilder` to main. Case ratings are aggregated and anonymous — `ai_judges` and `judge_name` are always empty.
- [x] 1.4 Omit `custom_headers` and `basic_auth_credential` from search endpoint export (`_search_endpoint.json.jbuilder`) to avoid leaking secrets. Credentials are instance-specific; imported endpoints work without them until configured.

## 2. Import changes — BookImporter

- [x] 2.1 Add AI judge validation in `BookImporter#validate` — collect `judge_name` values, match by name, create with placeholder key if `force_create_users`
- [x] 2.2 Update `BookImporter#import` — resolve `judge_name` to AI judge user when creating judgements, fall back to `user_email`
- [x] 2.3 Associate resolved AI judges with `book.ai_judges` HABTM after import

## 3. Import changes — CaseImporter

- [x] 3.1 **REVERT AI judge code**: Remove `include JudgeImportable`, `@ai_judge_definitions`, `build_ai_judge_definitions`, `validate_ai_judges`, `resolve_user_by_judge_name_or_email` from `CaseImporter`. Case ratings never have `judge_name` so this is dead code.
- [x] 3.2 **KEEP bug fixes**: Restore main's inline human-user `force_create_users` validation. Keep the `render` → `return false` fix (service shouldn't call controller methods) and the `loose` → `lose` typo fix.

## 4. API endpoint changes

- [x] 4.1 Expose `force_create_users` param on `POST /api/import/books` endpoint
- [x] 4.2 Expose `force_create_users` param on `POST /api/import/cases` endpoint — **KEEP**, useful for human users

## 5. Tests

- [x] 5.1 Test book export includes `ai_judges` and `judge_name` on judgements
- [x] 5.2 Test book import with AI judge matching by name (existing judge reused)
- [x] 5.3 Test book import creates AI judge with placeholder key when `force_create_users` is true
- [x] 5.4 Test book import fails validation when AI judge missing and `force_create_users` is false
- [x] 5.5 Test API book import endpoint accepts `force_create_users` param
- [x] 5.6 Test API case import endpoint accepts `force_create_users` param
- [x] 5.7 Test backward compatibility — import without `ai_judges`/`judge_name` works as before
- [x] 5.8 **REVERT AI judge case import tests**: Remove 3 AI judge tests from `cases_controller_test.rb` (lines 190-268: `imports case with AI judge rating matched by name`, `force_create_users creates missing AI judge with placeholder key`, `fails when AI judge missing and force_create_users is false`). Keep the human user `force_create_users` test (lines 168-188).
