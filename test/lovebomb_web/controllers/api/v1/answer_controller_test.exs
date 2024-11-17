defmodule LovebombWeb.Api.V1.AnswerControllerTest do
  use LovebombWeb.ConnCase

  import Lovebomb.AccountsFixtures
  alias Lovebomb.Questions

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, question} = Questions.create_question(%{
      content: "What is your favorite shared memory together?",  # Made longer to meet validation
      category: "relationship",
      difficulty_level: 1,
      min_level: 1,
      active: true,
      score_value: 10
    })

    {:ok, token, _claims} = Lovebomb.Guardian.encode_and_sign(user)
    authed_conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: authed_conn, user: user, question: question}
  end

  describe "create answer" do
    test "creates and renders answer when data is valid", %{conn: conn, user: user, question: question} do
      answer_params = %{
        "content" => "My thoughtful answer about our first date together. It was magical!",
        "question_id" => question.id,
        "difficulty_rating" => 3
      }

      conn = post(conn, ~p"/api/v1/answers", answer: answer_params)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      # Store the user ID in a variable for pattern matching
      user_id = user.id
      question_id = question.id

      conn = get(conn, ~p"/api/v1/answers/#{id}")
      assert %{
        "id" => ^id,
        "content" => "My thoughtful answer about our first date together. It was magical!",
        "skipped" => false,
        "difficulty_rating" => 3,
        "user_id" => ^user_id,
        "question_id" => ^question_id
      } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/answers", answer: %{})
      assert %{"error" => %{"details" => errors}} = json_response(conn, 422)
      assert errors != %{}
      assert "can't be blank" in (errors["question_id"] || [])
    end

    test "handles skipped questions properly", %{conn: conn, question: question} do
      answer_params = %{
        "question_id" => question.id,
        "skipped" => true,
        "skip_reason" => "Not comfortable answering this right now"
      }

      conn = post(conn, ~p"/api/v1/answers", answer: answer_params)
      response = json_response(conn, 201)["data"]
      assert response["skipped"] == true
      assert response["skip_reason"] == "Not comfortable answering this right now"
    end
  end

  describe "index" do
    setup %{user: user, question: question} do
      # Create some test answers
      {:ok, answer1} = Questions.submit_answer(user.id, question.id, %{
        "content" => "Our first vacation together was amazing! We went to the beach."
      })
      {:ok, answer2} = Questions.submit_answer(user.id, question.id, %{
        "content" => "I'll never forget when we cooked our first meal together."
      })

      {:ok, answers: [answer1, answer2]}
    end

    test "lists all answers for user", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/answers")
      response = json_response(conn, 200)
      assert length(response["data"]) == 2
    end

    test "filters answers by date range", %{conn: conn} do
      from_date = Date.utc_today() |> Date.to_iso8601()

      conn = get(conn, ~p"/api/v1/answers", from: from_date)
      response = json_response(conn, 200)
      assert length(response["data"]) == 2
    end
  end

  describe "show" do
    setup %{user: user, question: question} do
      {:ok, answer} = Questions.submit_answer(user.id, question.id, %{
        "content" => "Test answer"
      })
      {:ok, answer: answer}
    end

    test "shows answer details", %{conn: conn, answer: answer} do
      conn = get(conn, ~p"/api/v1/answers/#{answer.id}")
      response = json_response(conn, 200)
      assert response["data"]["id"] == answer.id
      assert response["data"]["content"] == "Test answer"
    end

    test "returns 404 for non-existent answer", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/api/v1/answers/00000000-0000-0000-0000-000000000000")
      end
    end
  end

  describe "react to answer" do
    setup %{user: user, question: question} do
      {:ok, answer} = Questions.submit_answer(user.id, question.id, %{
        "content" => "React to this"
      })
      {:ok, answer: answer}
    end

    test "adds reaction to answer", %{conn: conn, answer: answer} do
      conn = post(conn, ~p"/api/v1/answers/#{answer.id}/react", %{
        "reaction" => "❤️"
      })

      response = json_response(conn, 200)
      assert "❤️" in response["data"]["reactions"]
    end
  end
end
