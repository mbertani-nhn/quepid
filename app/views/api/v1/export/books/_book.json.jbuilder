# frozen_string_literal: true

json.name        book.name
json.show_rank   book.show_rank
json.support_implicit_judgements book.support_implicit_judgements

json.scale book.scale
json.scale_with_labels book.scale_with_labels

json.ai_judges do
  json.array! book.ai_judges do |judge|
    json.name           judge.name
    json.system_prompt  judge.system_prompt
    json.judge_options  judge.judge_options
  end
end

json.query_doc_pairs do
  json.array! book.query_doc_pairs,
              partial: 'query_doc_pair', as: :query_doc_pair
end
