# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module Import
      class BooksControllerTest < ActionController::TestCase
        let(:team) { teams(:shared) }
        let(:user) { users(:random) }
        let(:doug) { users(:doug) }
        let(:acase) { cases(:import_ratings_case) }
        let(:query) { queries(:import_ratings_query) }
        let(:book) { books(:james_bond_movies) }

        before do
          @controller = Api::V1::Import::BooksController.new

          login_user user
        end

        describe '#create' do
          test 'alerts when a team_id is not provided' do
            data = {
              name: 'test book',
            }
            assert_raises(ActionController::ParameterMissing) do
              post :create, params: { book: data, format: :json }
            end
          end
          test 'alerts when a user assocated with a judgement does not exist' do
            data = {
              name:              'test book',
              scale:             book.scale,
              scale_with_labels: book.scale_with_labels,
              query_doc_pairs:   [
                {
                  query_text: 'dog', doc_id: '123', position: 1,
                  judgements: [
                    {
                      rating:     1.0,
                      unrateable: false,
                      user_email: 'fakeuser@fake.com',
                      user_name:  'Fake',
                    },
                    {
                      rating:     2.0,
                      unrateable: false,
                      user_email: 'random@example.com',
                      user_name:  'Random User',
                    }
                  ]
                },
                { query_text: 'dog', doc_id: '234' },
                { query_text: 'dog', doc_id: '456',
                  judgements: [
                    {
                      rating:     1.0,
                      unrateable: false,
                    }
                  ] }
              ],
            }

            post :create, params: { book: data, team_id: team.id, format: :json }

            assert_response :bad_request

            body = response.parsed_body

            assert_includes body['base'], "User with email 'fakeuser@fake.com' needs to be migrated over first."
            assert_nil Book.find_by(name: 'test book')
          end

          test 'creates a new book' do
            data = {
              name:              'test book',
              scale:             book.scale,
              scale_with_labels: book.scale_with_labels,
              query_doc_pairs:   [
                {
                  query_text: 'dog', doc_id: '123',
                  judgements: [
                    {
                      rating:     1.0,
                      unrateable: false,
                      user_email: user.email,
                    },
                    {
                      rating:     2.0,
                      unrateable: false,
                      user_email: doug.email,
                    }
                  ]
                },
                { query_text: 'dog', doc_id: '234' },
                { query_text: 'dog', doc_id: '456',
                  judgements: [
                    {
                      rating:     1.0,
                      unrateable: false,
                    }
                  ] }
              ],
            }

            post :create, params: { book: data, team_id: team.id, format: :json }

            assert_response :created

            @book = Book.find_by(name: 'test book')

            assert_not_nil @book

            assert_equal 3, @book.query_doc_pairs.count
            assert_equal 3, @book.judgements.count

            response.parsed_body
          end

          test 'force_create_users creates missing human users' do
            data = {
              name:              'force create book',
              scale:             book.scale,
              scale_with_labels: book.scale_with_labels,
              query_doc_pairs:   [
                {
                  query_text: 'dog', doc_id: '123', position: 1,
                  judgements: [
                    { rating: 1.0, user_email: 'newuser@example.com' },
                  ],
                },
              ],
            }

            assert_not User.exists?(email: 'newuser@example.com')

            post :create, params: { book: data, team_id: team.id, force_create_users: true, format: :json }

            assert_response :created
            assert User.exists?(email: 'newuser@example.com')
          end

          test 'imports book with AI judge matched by name' do
            judge = users(:judge_judy)
            data = {
              name:              'ai judge book',
              scale:             book.scale,
              scale_with_labels: book.scale_with_labels,
              ai_judges:         [
                { name: judge.name, system_prompt: judge.system_prompt, judge_options: judge.judge_options },
              ],
              query_doc_pairs:   [
                {
                  query_text: 'dog', doc_id: '123', position: 1,
                  judgements: [
                    { rating: 2.0, judge_name: judge.name },
                  ],
                },
              ],
            }

            post :create, params: { book: data, team_id: team.id, format: :json }

            assert_response :created

            imported_book = Book.find_by(name: 'ai judge book')
            assert_not_nil imported_book
            assert_equal 1, imported_book.judgements.count
            assert_equal judge, imported_book.judgements.first.user
            assert_includes imported_book.ai_judges, judge
          end

          test 'force_create_users creates missing AI judge with placeholder key' do
            data = {
              name:              'new ai judge book',
              scale:             book.scale,
              scale_with_labels: book.scale_with_labels,
              ai_judges:         [
                {
                  name:          'Imported Judge',
                  system_prompt: 'You evaluate results.',
                  judge_options: { llm_provider: 'openai', llm_model: 'gpt-4o' },
                },
              ],
              query_doc_pairs:   [
                {
                  query_text: 'dog', doc_id: '123', position: 1,
                  judgements: [
                    { rating: 1.0, judge_name: 'Imported Judge' },
                  ],
                },
              ],
            }

            post :create, params: { book: data, team_id: team.id, force_create_users: true, format: :json }

            assert_response :created

            created_judge = User.only_ai_judges.find_by(name: 'Imported Judge')
            assert_not_nil created_judge
            assert_equal 'REPLACE_ME', created_judge.llm_key
            assert_equal 'You evaluate results.', created_judge.system_prompt
          end

          test 'fails when AI judge missing and force_create_users is false' do
            data = {
              name:              'missing judge book',
              scale:             book.scale,
              scale_with_labels: book.scale_with_labels,
              query_doc_pairs:   [
                {
                  query_text: 'dog', doc_id: '123', position: 1,
                  judgements: [
                    { rating: 1.0, judge_name: 'Ghost Judge' },
                  ],
                },
              ],
            }

            post :create, params: { book: data, team_id: team.id, format: :json }

            assert_response :bad_request
            body = response.parsed_body
            assert_includes body['base'], "AI judge 'Ghost Judge' needs to be migrated over first."
          end
        end
      end
    end
  end
end
