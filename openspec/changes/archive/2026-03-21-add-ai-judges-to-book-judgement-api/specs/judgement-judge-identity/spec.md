## ADDED Requirements

### Requirement: Judgement responses include judge identity
The judgement JSON partial SHALL include `judge_name` for AI judge judgements and `user_email` for human judge judgements.

#### Scenario: AI judge judgement
- **WHEN** a judgement is made by an AI judge
- **THEN** the response includes `judge_name` set to the judge's name and does NOT include `user_email`

#### Scenario: Human judge judgement
- **WHEN** a judgement is made by a human user
- **THEN** the response includes `user_email` set to the user's email and does NOT include `judge_name`

#### Scenario: Anonymous judgement
- **WHEN** a judgement has no associated user
- **THEN** the response includes neither `judge_name` nor `user_email`

### Requirement: No duplicate rating field
The judgement JSON partial SHALL include `rating` exactly once.

#### Scenario: Single rating field
- **WHEN** a judgement is serialized
- **THEN** `rating` appears once in the response

### Requirement: No N+1 queries for judgement users
The judgements controller SHALL eager-load the `user` association when listing judgements.

#### Scenario: Index action eager-loads users
- **WHEN** the judgements index action loads judgements for a book
- **THEN** it uses `includes(:user)` to prevent N+1 queries
