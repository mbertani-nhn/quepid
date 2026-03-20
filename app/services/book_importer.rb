# frozen_string_literal: true

require 'progress_indicator'

class BookImporter
  # include ProgressIndicator
  include JudgeImportable

  attr_reader :logger, :options

  def initialize book, current_user, data_to_process, opts = {}
    default_options = {
      logger:             Rails.logger,
      show_progress:      false,
      force_create_users: false,
    }

    @options = default_options.merge(opts.deep_symbolize_keys)

    @book = book
    @current_user = current_user
    @data_to_process = data_to_process
    @logger = @options[:logger]
    @ai_judge_definitions = {}
  end

  def validate
    params_to_use = @data_to_process

    @book.scale = params_to_use[:scale]
    @book.scale_with_labels = params_to_use[:scale_with_labels] if params_to_use[:scale_with_labels].present?

    build_ai_judge_definitions(params_to_use)

    return unless params_to_use[:query_doc_pairs]

    judge_names = []
    email_list = []

    params_to_use[:query_doc_pairs].each do |query_doc_pair|
      next unless query_doc_pair[:judgements]

      query_doc_pair[:judgements].each do |judgement|
        if judgement[:judge_name].present?
          judge_names << judgement[:judge_name]
        elsif judgement[:user_email].present?
          email_list << judgement[:user_email]
        end
      end
    end

    # Phase 1: Validate AI judges (fail early)
    validate_ai_judges(judge_names.uniq, @book)

    # Phase 2: Validate human users
    validate_human_users(email_list.uniq, @book)
  end

  def import
    params_to_use = @data_to_process

    @book.name = params_to_use[:name]
    @book.show_rank = params_to_use[:show_rank]
    @book.support_implicit_judgements = params_to_use[:support_implicit_judgements]

    # Set scale information (already set in validate, but ensure it's persisted)
    if params_to_use[:scorer]
      scorer_data = params_to_use[:scorer]
      @book.scale = scorer_data[:scale] if scorer_data[:scale].present?
      @book.scale_with_labels = scorer_data[:scale_with_labels] if scorer_data[:scale_with_labels].present?
    elsif params_to_use[:scale]
      @book.scale = params_to_use[:scale]
      @book.scale_with_labels = params_to_use[:scale_with_labels] if params_to_use[:scale_with_labels].present?
    end

    # Force the imported book to be owned by the user doing the importing.  Otherwise you can lose the book!
    @book.owner = User.find_by(email: @current_user.email)

    @book.save

    associate_ai_judges_with_book(params_to_use)
    import_query_doc_pairs(params_to_use)
  end

  private

  def associate_ai_judges_with_book params_to_use
    judge_names = []

    params_to_use[:query_doc_pairs]&.each do |qdp|
      qdp[:judgements]&.each do |j|
        judge_names << j[:judge_name] if j[:judge_name].present?
      end
    end

    judge_names.uniq.each do |name|
      judge = User.only_ai_judges.find_by(name: name)
      @book.ai_judges << judge if judge && @book.ai_judges.exclude?(judge)
    end
  end

  # rubocop:disable Metrics/MethodLength
  def import_query_doc_pairs params_to_use
    return unless params_to_use[:query_doc_pairs]

    total = params_to_use[:query_doc_pairs].size
    counter = total
    last_percent = 0
    params_to_use[:query_doc_pairs].each do |query_doc_pair|
      qdp = @book.query_doc_pairs.create(query_doc_pair.except(:judgements))
      counter -= 1
      percent = (((total - counter).to_f / total) * 100).truncate
      if percent > last_percent
        last_percent = percent
        Turbo::StreamsChannel.broadcast_render_to(
          :notifications,
          target:  'notifications',
          partial: 'books/blah',
          locals:  { book: @book, counter: counter, percent: percent, qdp: qdp }
        )
      end
      next unless query_doc_pair[:judgements]

      query_doc_pair[:judgements].each do |judgement|
        judgement[:user] = resolve_user_by_judge_name_or_email(judgement)
        qdp.judgements.create(judgement.except(:user_email, :judge_name))
      end
    end
  end
  # rubocop:enable Metrics/MethodLength
end
