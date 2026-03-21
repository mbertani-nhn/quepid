# frozen_string_literal: true

json.judgement_id judgement.id
json.rating judgement.rating
json.query_doc_pair_id judgement.query_doc_pair_id
json.unrateable judgement.unrateable
json.judge_later judgement.judge_later
json.user_id judgement.user_id
json.user_email     judgement.user&.email unless judgement.user&.ai_judge?
json.judge_name     judgement.user&.name if judgement.user&.ai_judge?
json.explanation judgement.explanation
