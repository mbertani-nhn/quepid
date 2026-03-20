## ClaudeOnRails Configuration

You are working on Quepid, a Rails application. Review the ClaudeOnRails context file at @.claude-on-rails/context.md

We run Quepid in Docker primarily, don't run Rails and other build tasks locally..

To set up the envirnoment use:

`bin/setup_docker`.

To start rails:

`bin/docker s`

Most commands you want to run you can just prefix with `bin/docker r bundle exec` so `rails console --environment=test` becomes `bin/docker r bundle exec rails console --environment=test`

Use yarn instead of npm for package management.

Run javascript tests via `bin/docker r yarn test`.


Documentation goes in the `docs` directory, not a toplevel `doc` directory.

To understand the data model used by Quepid, consult `./docs/data_mapping.md`.

To understand how the application is built, consult `./docs/app_structure.md`.


Instead of treating true/false parameters as strings in controller methods use our helper `archived = deserialize_bool_param(params[:archived])` to make them booleans.

We use .css, we do not use .scss.

Never do $window.location.href= '/', do $window.location.href= caseTryNavSvc.getQuepidRootUrl();.

Likewise urls generated should never start with / as we need relative links.

In Ruby we say `credentials?` versus `has_credentials?` for predicates.

In JavaScript, use `const` or `let` instead of `var`. When writing multiline ternary expressions, keep `?` and `:` at the end of the line, not the start of the next line, to avoid JSHint "misleading line break" errors.

## Testing

Ruby tests use Minitest (not RSpec) and live in `test/`. Run a specific test file:

`bin/docker r bundle exec rails test test/controllers/api/v1/import/books_controller_test.rb`

Run all tests in a directory:

`bin/docker r bundle exec rails test test/controllers/api/v1/export/`

JavaScript tests (Karma/Jasmine) live in `spec/javascripts/` — run via `bin/docker r yarn test`.

After modifying JavaScript source files in `app/assets/javascripts/`, rebuild the bundles:

`bin/docker r yarn build`

The build output (`app/assets/builds/`) is gitignored and generated at build time. The Docker container may serve stale JS if you don't rebuild.

## Data model gotchas

**JSON serialization split:** Some columns use `serialize :field, coder: JSON` (string column, Rails deserializes) while others use native `t.json` columns (MySQL handles it). Both return Ruby Hashes/Arrays, but they show up differently in the schema. Check `db/schema.rb` to know which you're dealing with.

Models with `serialize coder: JSON`: `SearchEndpoint.custom_headers`, `QueryDocPair.document_fields`, `Scorer.scale_with_labels`, `Score.queries`, `Book.scale_with_labels`, `MapperWizardState.custom_headers`.

Tables with native JSON columns (`options`): `cases`, `queries`, `query_doc_pairs`, `search_endpoints`.

**When these JSON-serialized fields hit the API**, jbuilder renders them as JSON objects (not strings). The AngularJS frontend may need to `JSON.stringify()` them before passing to directives like `ui-ace` that require string models.

**AI judges** are `User` records with `llm_key IS NOT NULL`. Use `User.only_ai_judges` scope. They skip email/password validation. The `llm_key` is encrypted (`encrypts :llm_key`).

**Cases vs Books:** Cases store one aggregated `Rating` per query/doc pair (no `user_id`). Books store individual `Judgement` records per judge per `QueryDocPair`. When syncing book judgements to a case, `RatingsManager` aggregates them — individual judge identity is lost.

## Export/Import

**Secrets are never exported.** `llm_key` on AI judges and `custom_headers`/`basic_auth_credential` on search endpoints are omitted from export JSON. On import, AI judges get `llm_key: "REPLACE_ME"` and search endpoints are created without credentials.

The `_search_endpoint.json.jbuilder` partial is shared between normal API responses and export. Use the `export` local variable (`export ||= false`) to conditionally exclude fields.

Business logic for import lives in service objects: `BookImporter`, `CaseImporter`. Shared AI judge matching logic is in `JudgeImportable` concern.

## API views (jbuilder)

API responses use jbuilder templates in `app/views/api/v1/`. Export views live under `app/views/api/v1/export/`. Some partials are shared between normal API responses and export — use local variables (e.g. `export ||= false`) to conditionally include/exclude fields.

## AngularJS frontend

The frontend is a legacy AngularJS 1.x app. Key patterns:

- **Directives** use isolate scopes with `scope: { settings: '=' }` for two-way binding.
- **Services** (e.g. `settingsSvc`, `searchEndpointSvc`) are singletons that hold state and are injected into controllers.
- **Factories** (e.g. `TryFactory`, `SettingsFactory`) are constructor functions that create model objects from API responses. They map snake_case API fields to camelCase JS properties (and back via `toApiFormat()`).
- The `ui-ace` directive requires **string** models. Any JSON objects from the API must be `JSON.stringify()`'d before binding.
- `angular.copy()` deep-copies objects but the copies lose their prototype methods — they become plain objects.