# Data Mapping

## Users/Teams

The `User` model is a typical model used for authenticating and authorizing a user in the app.

Everything starts with a user. The user owns entities they create, so if a user is removed all associated objects are removed as well.

In order to share stuff (eg. cases, scorers, etc) with other users, a user can create a `Team` and add any existing user to the team. Anything shared with a team is then shared with any members of the team.
The user that creates a `Team` is both the owner of the team and a member in the team.

## Live interactions with Search Engine

Everything related with search starts with the `Case` model.
A case is an entity that encompasses everything that has to do with an experiment or a test or work to be done in relations to a search setup.

The `Case` itself is a connector of all of the different elements that go with it and serves as the central place to get to other entities. The main attribute of a case is its `name`.

A case has many queries. A `Query` is a representation of a search term and all of its relevant info.
A query starts with the `query_text`, but can also have `notes` or `options` associated with it. Queries can also be re-ordered within a case.
A query returns results from the search engine, but those results are not saved or modeled in Quepid, Quepid does not keep track of search results. However, each results can be assigned a `Rating`.

A rating is associated to the query using the `query_id` foreign key and to a search results through the `doc_id` attribute. The `doc_id` is the only thing Quepid saves related to search results. Note that case ratings are architecturally anonymous — even when a human rates directly in the UI, the `Rating` record is created without `user_id`.

Ratings for each result are summed up and turned into query score using a `Scorer`. Each query can either have a specific unit test style scorer, or use the case scorer. Scorers can be created by a user to be used on cases and shared with teams, or be created in an ad-hoc manner directly for a query as a unit test.  There is an argument for unit test style scorers should be their own model and not shared with case level scorers.

The score of each query is transformed into a percentile score for the case, and saved as a time series as the `Score` model. The user can also create an `Annotation` which would be associated to a score, in order to save notes throughout time to indicate what changes were made that resulted in a different case score.

Each case has its own settings, and those settings or configs are saved in the `Try` model. Each time the configs are changed, a new `Try` record is created in the db to keep a history of the changes throughout time. Tries represent tweaks where developers fiddle with the search engine configs and test the results. A history is kept in order to make it easy to go back to a point in time and start over.

A `Try` connects to the individual Search engine via a `SearchEndpoint`.   The `SearchEndpoint` has a variety of properties that configure access. Supported search engines include Solr, Elasticsearch, OpenSearch, Vectara, Algolia, and custom SearchAPI endpoints.  The SearchAPI variation of a `SearchEndpoint` lets you provide some custom JavaScript to map from any search response format to the specific one that Quepid expects.  A `SearchEndpoint` can also store `custom_headers` (e.g. API keys) and `basic_auth_credential` for authentication.  The `custom_headers` field is serialized as JSON in the database and stored as a JSON object (e.g. `{"Authorization": "ApiKey xxx"}`).

The last remaining piece of the puzzle is `Snapshot`/`SnapshotQuery`/`SnapshotDoc`. A snapshot represents a snapshot of a point in time in history of queries and search results. The `Snapshot` model itself has a `name`, a reference to the case, and a time stamp. `SnapshotQuery` is a join model between a `Query` and a `Snapshot`. And a `SnapshotDoc` represents the `doc_id` of the result as well as the position they appear at in the search results at the time the snapshot was taken.

## Collecting Feedback on Search Quality

To support collecting search feedback from multiple Users, we introduced a similar data structure to Cases/Queries/Ratings that starts with a `Book`.   A `Book` represents a set of queries and their results, modeled as `QueryDocPair`'s.   Each `QueryDocPair` can have multiple `Judgements`, each made by a unique `User`.

Unlike a `Case` datamodel that is meant for live interaction with a SearchEndpoint, the Book is meant to support a offline interaction model for gathering Judgements.

The data modeled by a Book can be imported back into a Case.  The `RatingsManager` takes all the Judgements for a QueryDocPair and aggregates them into a single Rating using an optimistic-pessimistic algorithm: with 1-2 judgements it averages them; with 3+ it takes the top 3 ratings and uses that value if they agree, or falls back to the minimum of the top 3 if they disagree (trusting the pessimistic judge). This aggregated rating is stored in the corresponding Query in the Case — individual judge identity is lost in the process.

## AI Judges

AI judges are `User` records with `llm_key IS NOT NULL`.  They can be queried via the `User.only_ai_judges` scope.  AI judges skip the normal email/password validation that regular users require.  The `llm_key` field is encrypted at rest using ActiveRecord encryption (see `docs/ENCRYPTION_SETUP.md`).

Each AI judge stores its configuration in two places:
- `system_prompt` — the prompt template used when judging query/document pairs
- `judge_options` — a JSON blob stored within the user's `options` field, containing provider-specific settings like `llm_provider`, `llm_model`, `llm_service_url`, `llm_timeout`, and optionally `llm_api_version`

Supported LLM providers include OpenAI, Anthropic, Azure OpenAI, Azure AI Foundry (including Anthropic models via Azure AI Foundry), Google Gemini, Cohere, and Ollama.  The `LlmService` routes to the appropriate API based on the `llm_provider` value in `judge_options`.

A `Book` has a many-to-many relationship with AI judges via the `books_ai_judges` join table.  When an AI judge is used to judge a Book, each judgement is stored as a `Judgement` record with the judge's `user_id`, preserving per-judge identity, ratings, and explanations.

## Export and Import

Cases and Books can be exported as JSON and imported on another Quepid instance.

**Secrets are never exported.** The `llm_key` on AI judges, `custom_headers` (which may contain API keys), and `basic_auth_credential` on search endpoints are all omitted from the export JSON.  On import, AI judges are created with `llm_key: "REPLACE_ME"` and search endpoints are created without credentials — both need to be configured on the target instance.

**Book export** includes a top-level `ai_judges` array with each judge's name, system_prompt, and judge_options.  Each judgement includes `judge_name` for AI-judge-authored judgements and `user_email` for human users.  On import, AI judges are matched by name (not email).  If a matching judge exists, it is reused; if missing and `force_create_users` is true, a new judge is created with placeholder credentials.

**Case export** does not include AI judge information.  Case ratings are aggregated and anonymous (no `user_id`), so there is no per-judge identity to export.  The case export includes query groupings, search endpoint configuration (minus credentials), and try settings.  On import, `force_create_users` can be used to auto-create missing human users.

Import logic lives in `BookImporter` and `CaseImporter` service objects, with shared AI judge matching in the `JudgeImportable` concern.

## Other

Quepid provides scorers that are written by the OSC team for everyone to use, those `Scorer`'s are tagged with the `communal` flag as `true`, and the default scorers are created when seeding the db (using `bin/rake db:seed` or `bin/rake db:setup`).

## Entity Resolution Diagram

![model diagram](erd.png).
