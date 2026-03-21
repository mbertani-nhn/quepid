## 1. Book API — add ai_judges

- [x] 1.1 Add ai_judges block to `app/views/api/v1/books/_book.json.jbuilder`
- [x] 1.2 Add `includes(:ai_judges)` to index and set_book in `app/controllers/api/v1/books_controller.rb`
- [x] 1.3 Add test for ai_judges in book show response in `test/controllers/api/v1/books_controller_test.rb`

## 2. Judgement API — add judge identity

- [x] 2.1 Add judge_name and user_email to `app/views/api/v1/judgements/_judgement.json.jbuilder` and remove duplicate rating line
- [x] 2.2 Add `includes(:user)` to index action in `app/controllers/api/v1/judgements_controller.rb`
- [x] 2.3 Add test for judge_name/user_email in judgement index response in `test/controllers/api/v1/judgements_controller_test.rb`

## 3. Verify

- [x] 3.1 Run existing book and judgement controller tests to confirm no regressions
