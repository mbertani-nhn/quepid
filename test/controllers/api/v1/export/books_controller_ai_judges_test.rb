# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module Export
      class BooksControllerAiJudgesTest < ActionController::TestCase
        let(:doug) { users(:doug) }
        let(:judge) { users(:judge_judy) }
        let(:book) { books(:james_bond_movies) }

        before do
          @controller = Api::V1::Export::BooksController.new
          login_user doug
        end

        test 'book export includes ai_judges array' do
          # james_bond_movies already has judge_judy as an AI judge via fixture
          post :update, params: { book_id: book.id }
          assert_response :ok

          perform_enqueued_jobs

          post :update, params: { book_id: book.id }
          assert_response :ok
          body = response.parsed_body

          assert_not_nil body['download_file_url']

          # Download and parse the exported JSON
          export_json = extract_book_export(book)

          assert_not_nil export_json['ai_judges']
          assert_equal 1, export_json['ai_judges'].length

          ai_judge = export_json['ai_judges'].first
          assert_equal judge.name, ai_judge['name']
          assert_equal judge.system_prompt, ai_judge['system_prompt']
          assert_not_nil ai_judge['judge_options']
          # llm_key should NOT be in the export
          assert_nil ai_judge['llm_key']
        end

        test 'judgement by AI judge exports judge_name instead of user_email' do
          # Create a judgement by the AI judge
          qdp = book.query_doc_pairs.first
          qdp.judgements.create!(user: judge, rating: 2.5, explanation: 'AI says good')

          post :update, params: { book_id: book.id }
          perform_enqueued_jobs
          post :update, params: { book_id: book.id }

          export_json = extract_book_export(book)

          ai_judgements = export_json['query_doc_pairs']
            .flat_map { |qdp| qdp['judgements'] || [] }
            .select { |j| j['judge_name'].present? }

          assert_not_empty ai_judgements
          assert_equal judge.name, ai_judgements.first['judge_name']
          assert_nil ai_judgements.first['user_email']
        end

        private

        def extract_book_export exported_book
          exported_book.reload
          blob = exported_book.export_file
          zip_data = blob.download
          Zip::InputStream.open(StringIO.new(zip_data)) do |io|
            while (entry = io.get_next_entry)
              return JSON.parse(io.read) if entry.name.end_with?('.json')
            end
          end
        end
      end
    end
  end
end
