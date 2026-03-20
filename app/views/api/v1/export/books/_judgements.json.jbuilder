# frozen_string_literal: true

json.rating         judgement.rating
json.unrateable     judgement.unrateable
json.judge_later    judgement.judge_later
json.user_email     judgement.user&.email unless judgement.user&.ai_judge?
json.judge_name     judgement.user.name if judgement.user&.ai_judge?
json.explanation    judgement.explanation
