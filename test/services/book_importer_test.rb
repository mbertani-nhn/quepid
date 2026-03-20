# frozen_string_literal: true

require 'test_helper'

class BookImporterTest < ActiveSupport::TestCase
  let(:user) { users(:random) }
  let(:judge) { users(:judge_judy) }
  let(:book) { books(:james_bond_movies) }

  describe 'AI judge import by name' do
    test 'reuses existing AI judge when matched by name' do
      new_book = Book.new
      data = {
        name:            'Test Book',
        scale:           '0,1,2,3',
        ai_judges:       [
          { name: judge.name, system_prompt: 'Different prompt', judge_options: { llm_model: 'other-model' } },
        ],
        query_doc_pairs: [
          {
            query_text: 'test', doc_id: '1', position: 1,
            judgements: [{ rating: 2.0, judge_name: judge.name }],
          },
        ],
      }

      importer = BookImporter.new(new_book, user, data)
      importer.validate

      assert_empty new_book.errors.full_messages

      importer.import

      created_book = Book.find_by(name: 'Test Book')
      assert_not_nil created_book
      assert_equal 1, created_book.judgements.count
      assert_equal judge, created_book.judgements.first.user

      # Existing judge should NOT be overwritten
      judge.reload
      assert_equal '1234asdf5678', judge.llm_key
    end

    test 'creates AI judge with placeholder key when force_create_users is true' do
      new_book = Book.new
      data = {
        name:            'Test Book',
        scale:           '0,1',
        ai_judges:       [
          {
            name:          'Brand New Judge',
            system_prompt: 'You are a test judge.',
            judge_options: { llm_provider: 'openai', llm_model: 'gpt-4o', llm_service_url: 'https://api.openai.com' },
          },
        ],
        query_doc_pairs: [
          {
            query_text: 'test', doc_id: '1', position: 1,
            judgements: [{ rating: 1.0, judge_name: 'Brand New Judge' }],
          },
        ],
      }

      assert_not User.only_ai_judges.exists?(name: 'Brand New Judge')

      importer = BookImporter.new(new_book, user, data, { force_create_users: true })
      importer.validate

      assert_empty new_book.errors.full_messages

      created_judge = User.only_ai_judges.find_by(name: 'Brand New Judge')
      assert_not_nil created_judge
      assert_equal 'REPLACE_ME', created_judge.llm_key
      assert_equal 'You are a test judge.', created_judge.system_prompt
      assert_equal 'openai', created_judge.judge_options[:llm_provider]

      importer.import

      created_book = Book.find_by(name: 'Test Book')
      assert_equal created_judge, created_book.judgements.first.user
      assert_includes created_book.ai_judges, created_judge
    end

    test 'fails validation when AI judge missing and force_create_users is false' do
      new_book = Book.new
      data = {
        name:            'Test Book',
        scale:           '0,1',
        query_doc_pairs: [
          {
            query_text: 'test', doc_id: '1', position: 1,
            judgements: [{ rating: 1.0, judge_name: 'Nonexistent Judge' }],
          },
        ],
      }

      importer = BookImporter.new(new_book, user, data)
      importer.validate

      assert_includes new_book.errors.full_messages, "AI judge 'Nonexistent Judge' needs to be migrated over first."
    end

    test 'backward compatible with old format (no ai_judges or judge_name)' do
      new_book = Book.new
      data = {
        name:            'Old Format Book',
        scale:           '0,1',
        query_doc_pairs: [
          {
            query_text: 'test', doc_id: '1', position: 1,
            judgements: [{ rating: 1.0, user_email: user.email }],
          },
        ],
      }

      importer = BookImporter.new(new_book, user, data)
      importer.validate

      assert_empty new_book.errors.full_messages

      importer.import

      created_book = Book.find_by(name: 'Old Format Book')
      assert_equal user, created_book.judgements.first.user
    end
  end
end
