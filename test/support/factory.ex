defmodule Lovebomb.Factory do
  use ExMachina.Ecto, repo: Lovebomb.Repo

  def user_factory do
    %Lovebomb.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      username: sequence(:username, &"user#{&1}"),
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      active: true,
      level: 1,
      current_score: 0,
      points: 0,
      highest_level: 1,
      questions_answered: 0,
      streak_days: 0,
      interaction_count: 0,
      stats: %{
        "total_interactions" => 0,
        "interaction_types" => %{},
        "monthly_activity" => %{},
        "achievements" => [],
        "question_categories" => %{},
        "response_times" => %{}
      }
    }
  end

  def partnership_factory do
    user = build(:user)    # Build but don't insert user
    partner = build(:user) # Build but don't insert partner

    # Insert both users
    user = insert(user)
    partner = insert(partner)

    # Build the partnership struct (but don't insert it)
    partnership = %Lovebomb.Accounts.Partnership{
      user_id: user.id,
      partner_id: partner.id,
      status: :pending,
      partnership_level: 1,
      streak_days: 0,
      interaction_count: 0,
      last_milestone: 0,
      achievements: [],
      mutual_answer_count: 0,
      longest_streak: 0,
      custom_settings: %{
        "notification_preferences" => %{
          "answers" => true,
          "daily_reminder" => true,
          "achievements" => true
        },
        "privacy_settings" => %{
          "share_streak" => true,
          "share_achievements" => true
        },
        "display_preferences" => %{
          "show_level" => true,
          "show_streak" => true
        }
      },
      stats: %{
        "questions_answered" => 0,
        "questions_skipped" => 0,
        "total_interaction_time" => 0,
        "average_response_time" => 0,
        "category_preferences" => %{},
        "monthly_activity" => %{}
      }
    }

    # Let ExMachina handle the insert
    partnership
  end

  # Helper function to create a partnership with its reverse
  def create_partnership_pair(partnership) do
    # Insert the primary partnership
    primary = insert(partnership)

    # Build and insert the reverse partnership
    reverse = build(:partnership, %{
      user_id: primary.partner_id,
      partner_id: primary.user_id,
      status: primary.status,
      partnership_level: primary.partnership_level
    })

    insert(reverse)

    primary
  end

  # Use this when you need both partnerships
  def partnership_with_reverse_factory do
    build(:partnership)
    |> create_partnership_pair()
  end

  def partnership_with_users_factory do
    partnership = insert(:partnership)

    # Create the reverse partnership using Accounts context
    reverse_attrs = %{
      user_id: partnership.partner_id,
      partner_id: partnership.user_id,
      status: partnership.status,
      partnership_level: partnership.partnership_level
    }

    {:ok, _reverse} = Lovebomb.Accounts.create_partnership(reverse_attrs)

    partnership
  end

  def profile_factory do
    %Lovebomb.Accounts.Profile{
      display_name: sequence(:display_name, &"User #{&1}"),
      preferences: %{}
    }
  end

  def question_factory do
    %Lovebomb.Questions.Question{
      content: sequence(:content, &"Test question #{&1}?"),
      difficulty_level: 5,
      category: "general",
      score_value: 10,
      min_level: 1,
      max_level: 100,
      tags: ["test"],
      active: true,
      language: "en",
      author_type: "system",
      metadata: %{
        "followup_questions" => [],
        "suggested_topics" => [],
        "emotional_tags" => [],
        "time_estimate" => "5m"
      },
      stats: %{
        "times_asked" => 0,
        "skip_rate" => 0.0,
        "avg_response_length" => 0,
        "avg_difficulty_rating" => 0.0,
        "category_performance" => %{}
      }
    }
  end

  def answer_factory do
    %Lovebomb.Questions.Answer{
      text: sequence(:text, &"Test answer #{&1}"),
      skipped: false,
      visibility: :partners_only,
      reactions: [],
      difficulty_rating: 5,
      metadata: %{
        "response_time" => nil,
        "edited_count" => 0,
        "last_edited_at" => nil,
        "word_count" => 0,
        "language" => "en"
      }
    }
  end

  def partnership_interaction_factory do
    %Lovebomb.Accounts.PartnershipInteraction{
      interaction_type: :message,
      content: %{text: "Hello!"},
      metadata: %{}
    }
  end

  # Helper functions for complex associations
  def with_user(factory_item) do
    insert(:user) |> associate_factory_item(factory_item)
  end

  def with_partnership(factory_item) do
    insert(:partnership_with_users) |> associate_factory_item(factory_item)
  end

  def with_question(factory_item) do
    insert(:question) |> associate_factory_item(factory_item)
  end

  defp associate_factory_item(parent, child) do
    association_field = association_field_for_parent(parent)
    Map.put(child, association_field, parent)
  end

  defp association_field_for_parent(%Lovebomb.Accounts.User{}), do: :user_id
  defp association_field_for_parent(%Lovebomb.Accounts.Partnership{}), do: :partnership_id
  defp association_field_for_parent(%Lovebomb.Questions.Question{}), do: :question_id
end
