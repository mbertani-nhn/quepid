## ADDED Requirements

### Requirement: Book export includes AI judge definitions
The book export SHALL include a top-level `ai_judges` array containing the configuration of each AI judge associated with the book via the `books_ai_judges` relationship.

#### Scenario: Book with AI judges exports judge definitions
- **WHEN** a book has AI judges associated via `books_ai_judges`
- **THEN** the export JSON SHALL include an `ai_judges` array where each entry contains `name`, `system_prompt`, and `judge_options`
- **AND** the `llm_key` SHALL NOT be included in the export

#### Scenario: Book with no AI judges exports empty array
- **WHEN** a book has no AI judges associated
- **THEN** the export JSON SHALL include `ai_judges` as an empty array

### Requirement: Book judgement export includes judge_name for AI judges
Each judgement in the book export SHALL include a `judge_name` field when the judgement was authored by an AI judge.

#### Scenario: AI-judge-authored judgement includes judge_name
- **WHEN** a judgement's user is an AI judge (`llm_key IS NOT NULL`)
- **THEN** the exported judgement SHALL include `judge_name` set to the AI judge's `name`
- **AND** `user_email` MAY be null

#### Scenario: Human-user-authored judgement has null judge_name
- **WHEN** a judgement's user is a regular human user
- **THEN** the exported judgement SHALL include `judge_name` as null
- **AND** `user_email` SHALL contain the user's email

### Requirement: Case export is NOT modified for AI judges
The case export SHALL NOT include `ai_judges` or `judge_name` on ratings. Case ratings are aggregated from book judgements by `RatingsManager` into a single `Rating` per query/doc pair with no `user_id`. Individual judge identity is preserved only in Books. Additionally, even human ratings created directly in the case UI are stored without `user_id` — case ratings are architecturally anonymous.

The aggregation algorithm (`RatingsManager.calculate_rating_from_judgements`) uses an optimistic-pessimistic approach:
- **1-2 judgements:** averaged
- **3+ judgements:** top 3 ratings taken; if all agree, that value is used; if they disagree, the minimum of the top 3 is used (pessimistic: trust the lower rating, assuming judges tend to overrate)

## REMOVED Requirements

### ~~Requirement: Case export includes AI judge definitions and judge_name on ratings~~ (REVERTED)
~~The case export SHALL include a top-level `ai_judges` array and `judge_name` on ratings authored by AI judges.~~

**Reason:** Case ratings are aggregated and anonymous (`user_id` is nil). These fields would always be empty. Per-judge detail is available via book export.

## KEPT Requirements (import side)

### Requirement: Book import matches AI judges by name
The `BookImporter` SHALL resolve AI judges by name during import, checking the `ai_judges` array and judgement `judge_name` fields.

#### Scenario: AI judge exists by name on target instance
- **WHEN** the import payload contains an AI judge with `name` matching an existing `User.only_ai_judges` record
- **THEN** the importer SHALL reuse the existing AI judge for judgement attribution
- **AND** SHALL NOT overwrite the existing judge's `llm_key`, `system_prompt`, or `judge_options`

#### Scenario: AI judge missing and force_create_users is true
- **WHEN** the import payload references an AI judge by `judge_name` that does not exist
- **AND** `force_create_users` is true
- **THEN** the importer SHALL create a new AI judge `User` with `name`, `system_prompt`, and `judge_options` from the `ai_judges` array
- **AND** SHALL set `llm_key` to `"REPLACE_ME"`

#### Scenario: AI judge missing and force_create_users is false
- **WHEN** the import payload references an AI judge by `judge_name` that does not exist
- **AND** `force_create_users` is false
- **THEN** the importer SHALL add a validation error and fail before processing query_doc_pairs

### Requirement: Case import matches AI judges by name for ratings
The `CaseImporter` SHALL resolve AI judges by `judge_name` in ratings using the same name-based matching as `BookImporter`.

#### Scenario: Case import resolves AI judge rating by name
- **WHEN** a case import contains a rating with `judge_name` set
- **THEN** the importer SHALL look up `User.only_ai_judges.find_by(name: judge_name)` and assign it to the rating

#### Scenario: Case import creates missing AI judge with force_create_users
- **WHEN** a case import references a `judge_name` not found in existing AI judges
- **AND** `force_create_users` is true
- **AND** the `ai_judges` array contains the judge definition
- **THEN** the importer SHALL create the AI judge with placeholder `llm_key: "REPLACE_ME"`

### Requirement: API book import endpoint exposes force_create_users
The `POST /api/import/books` endpoint SHALL accept `force_create_users` as a top-level boolean parameter.

#### Scenario: API book import with force_create_users true
- **WHEN** a client sends `POST /api/import/books` with `force_create_users: true`
- **THEN** the `BookImporter` SHALL receive `force_create_users: true` in its options

#### Scenario: API book import without force_create_users defaults to false
- **WHEN** a client sends `POST /api/import/books` without `force_create_users`
- **THEN** the `BookImporter` SHALL receive `force_create_users: false`

### Requirement: API case import endpoint exposes force_create_users
The `POST /api/import/cases` endpoint SHALL accept `force_create_users` as a top-level boolean parameter.

#### Scenario: API case import with force_create_users true
- **WHEN** a client sends `POST /api/import/cases` with `force_create_users: true`
- **THEN** the `CaseImporter` SHALL receive `force_create_users: true` in its options

### Requirement: Book import associates AI judges with the book
When AI judges are referenced in the import, the importer SHALL add them to `book.ai_judges` via the HABTM association.

#### Scenario: Imported book has AI judges associated
- **WHEN** a book import contains judgements with `judge_name` values
- **THEN** the corresponding AI judge users SHALL be added to `book.ai_judges`

### Requirement: Validation order — AI judges validated before query_doc_pairs
The importer SHALL validate AI judge existence before processing human users, to fail early.

#### Scenario: Missing AI judge fails validation before user check
- **WHEN** a book import references a non-existent AI judge and a non-existent human user
- **AND** `force_create_users` is false
- **THEN** the validation error for the AI judge SHALL be reported (human user error also reported, but AI judge is checked first)

### Requirement: Search endpoint credentials omitted from export
The case export SHALL NOT include `custom_headers` or `basic_auth_credential` in the search endpoint serialization. These fields contain secrets (API keys, auth tokens) that must not be serialized into shareable JSON.

#### Scenario: Case export omits search endpoint credentials
- **WHEN** a case with a search endpoint that has `custom_headers` and/or `basic_auth_credential` is exported
- **THEN** the export JSON SHALL NOT include `custom_headers` in the `search_endpoint` block
- **AND** SHALL NOT include `basic_auth_credential` in the `search_endpoint` block
- **AND** all other search endpoint fields (name, endpoint_url, search_engine, api_method, etc.) SHALL be included

#### Scenario: Case import creates endpoint without credentials
- **WHEN** a case is imported with a search endpoint that has no `custom_headers` or `basic_auth_credential`
- **AND** no matching search endpoint exists on the target instance
- **THEN** the importer SHALL create the search endpoint without credentials
- **AND** searches SHALL fail with 401 until the user configures credentials on the target instance

#### Scenario: Case import matches existing endpoint without credentials in query
- **WHEN** a case is imported with a search endpoint that omits credential fields
- **AND** a matching search endpoint exists (by name, endpoint_url, search_engine, etc.)
- **THEN** the importer SHALL reuse the existing endpoint with its locally configured credentials

### Requirement: Backward compatibility with old export format
Imports of book/case JSON that lack `ai_judges` and `judge_name` fields SHALL continue to work identically to pre-change behavior.

#### Scenario: Old-format book import without ai_judges or judge_name
- **WHEN** a book import payload has no `ai_judges` array and judgements have no `judge_name`
- **THEN** the importer SHALL fall back to email-only matching (existing behavior)
