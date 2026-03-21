## Why

The Python SDK workspace export fetches book details via `GET /api/books/:id` and judgements via `GET /api/books/:id/judgements`. Neither endpoint currently returns AI judge information — `ai_judges` is missing from book responses, and judgements only include `user_id` without `judge_name` or `user_email`. This blocks the SDK from preserving judge identity in workspace exports.

## What Changes

- Add `ai_judges` array (name, system_prompt, judge_options) to the book JSON partial, making it available in all book API responses (show, index, create, update).
- Add `judge_name` (for AI judges) and `user_email` (for human judges) to the judgement JSON partial, matching the export format.
- Remove duplicate `json.rating` line in the judgement partial.
- Add `includes(:ai_judges)` to books controller queries to avoid N+1.
- Add `includes(:user)` to judgements controller index to avoid N+1.

## Capabilities

### New Capabilities
- `book-ai-judges-response`: Include AI judge data in book API responses
- `judgement-judge-identity`: Include judge name and user email in judgement API responses

### Modified Capabilities

## Impact

- `app/views/api/v1/books/_book.json.jbuilder` — add ai_judges block
- `app/views/api/v1/judgements/_judgement.json.jbuilder` — add judge_name, user_email; fix duplicate rating
- `app/controllers/api/v1/books_controller.rb` — eager-load ai_judges
- `app/controllers/api/v1/judgements_controller.rb` — eager-load user
- Tests in `test/controllers/api/v1/books_controller_test.rb` and `test/controllers/api/v1/judgements_controller_test.rb`
