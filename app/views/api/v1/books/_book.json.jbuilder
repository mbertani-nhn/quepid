# frozen_string_literal: true

json.name        book.name
json.book_id     book.id

json.ai_judges do
  json.array! book.ai_judges do |judge|
    json.name           judge.name
    json.system_prompt  judge.system_prompt
    json.judge_options  judge.judge_options
  end
end
