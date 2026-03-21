## ADDED Requirements

### Requirement: Book API responses include AI judges
The book JSON partial SHALL include an `ai_judges` array containing each AI judge's `name`, `system_prompt`, and `judge_options`. The `llm_key` MUST NOT be included.

#### Scenario: Book with AI judges
- **WHEN** a client requests `GET /api/books/:id` for a book that has AI judges
- **THEN** the response includes an `ai_judges` array with each judge's name, system_prompt, and judge_options

#### Scenario: Book without AI judges
- **WHEN** a client requests `GET /api/books/:id` for a book with no AI judges
- **THEN** the response includes an empty `ai_judges` array

#### Scenario: Book list includes AI judges
- **WHEN** a client requests `GET /api/books`
- **THEN** each book in the response includes its `ai_judges` array

### Requirement: No N+1 queries for AI judges
The books controller SHALL eager-load the `ai_judges` association when loading books.

#### Scenario: Index action eager-loads
- **WHEN** the books index action loads books
- **THEN** it uses `includes(:ai_judges)` to prevent N+1 queries

#### Scenario: Show action eager-loads
- **WHEN** the books show action loads a single book
- **THEN** it uses `includes(:ai_judges)` to prevent N+1 queries
