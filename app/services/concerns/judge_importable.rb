# frozen_string_literal: true

module JudgeImportable
  extend ActiveSupport::Concern

  private

  def build_ai_judge_definitions params_to_use
    @ai_judge_definitions = {}
    params_to_use[:ai_judges]&.each do |judge_def|
      @ai_judge_definitions[judge_def[:name]] = judge_def if judge_def[:name].present?
    end
  end

  def validate_ai_judges judge_names, error_target
    judge_names.each do |name|
      next if User.only_ai_judges.exists?(name: name)

      if options[:force_create_users]
        create_ai_judge(name)
      else
        error_target.errors.add(:base, "AI judge '#{name}' needs to be migrated over first.")
      end
    end
  end

  def validate_human_users emails, error_target
    emails.each do |email|
      next if User.exists?(email: email)

      if options[:force_create_users]
        User.invite!({ email: email, password: '', skip_invitation: true }, @current_user)
      else
        error_target.errors.add(:base, "User with email '#{email}' needs to be migrated over first.")
      end
    end
  end

  def create_ai_judge name
    judge_def = @ai_judge_definitions[name] || {}

    judge = User.new(
      name:          name,
      llm_key:       'REPLACE_ME',
      system_prompt: judge_def[:system_prompt]
    )
    judge.judge_options = judge_def[:judge_options].to_h if judge_def[:judge_options].present?
    judge.save!
  end

  def resolve_user_by_judge_name_or_email record
    if record[:judge_name].present?
      User.only_ai_judges.find_by(name: record[:judge_name])
    elsif record[:user_email].present?
      User.find_by(email: record[:user_email])
    end
  end
end
