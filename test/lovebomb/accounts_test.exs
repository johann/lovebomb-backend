defmodule Lovebomb.AccountsTest do
  use Lovebomb.DataCase, async: true

  alias Lovebomb.Accounts
  alias Lovebomb.Accounts.{User, Partnership, Profile}
  alias Lovebomb.Repo

  import Lovebomb.Factory

  describe "user management" do
    @valid_user_attrs %{
      email: "test@example.com",
      password: "password123",
      username: "testuser"
    }
    @invalid_user_attrs %{email: nil, password: nil}

    test "create_user/1 with valid data creates a user and profile" do
      assert {:ok, %User{} = user} = Accounts.create_user(@valid_user_attrs)
      assert user.email == "test@example.com"
      assert user.username == "testuser"

      # Verify profile was created
      assert %Profile{} = profile = Repo.get_by(Profile, user_id: user.id)
      assert profile.display_name == "testuser"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_user_attrs)
    end

    test "get_user_by_email/1 returns user with matching email" do
      user = insert(:user)
      assert found_user = Accounts.get_user_by_email(user.email)
      assert found_user.id == user.id
    end

    test "get_user_by_email/1 returns nil for non-existent email" do
      assert is_nil(Accounts.get_user_by_email("nonexistent@example.com"))
    end

    test "authenticate_user/2 authenticates user with correct password" do
      user = insert(:user, password: "password123")
      assert {:ok, authenticated_user} = Accounts.authenticate_user(user.email, "password123")
      assert authenticated_user.id == user.id
    end

    test "authenticate_user/2 returns error with incorrect password" do
      user = insert(:user, password: "password123")
      assert {:error, :invalid_credentials} = Accounts.authenticate_user(user.email, "wrongpassword")
    end
  end

  describe "profile management" do
    setup do
      user = insert(:user)
      %{user: user}
    end

    test "create_initial_profile/1 creates profile with default values", %{user: user} do
      assert {:ok, profile} = Accounts.create_initial_profile(user.id)
      assert profile.user_id == user.id
      assert profile.display_name == user.username
      assert profile.preferences == %{}
    end

    test "update_profile/2 updates profile with valid data", %{user: user} do
      profile = insert(:profile, user_id: user.id)
      update_attrs = %{display_name: "New Name", preferences: %{theme: "dark"}}

      assert {:ok, updated_profile} = Accounts.update_profile(user.id, update_attrs)
      assert updated_profile.display_name == "New Name"
      assert updated_profile.preferences["theme"] == "dark"
    end
  end

  describe "partnership management" do
    setup do
      partnership = insert(:partnership)
      %{
        partnership: partnership,
        user: Repo.get!(User, partnership.user_id),
        partner: Repo.get!(User, partnership.partner_id)
      }
    end

    test "update_partnership_settings/2 updates settings for both partnerships", %{partnership: partnership} do
      settings = %{
        "notification_preferences" => %{
          "answers" => false,
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
      }

      assert {:ok, updated} = Accounts.update_partnership_settings(partnership, settings)
      assert updated.custom_settings["notification_preferences"]["answers"] == false

      # Verify reverse partnership
      reverse = Repo.get_by(Partnership,
        user_id: partnership.partner_id,
        partner_id: partnership.user_id
      )
      assert reverse.custom_settings["notification_preferences"]["answers"] == false
    end

    test "update_partnership_status/3 updates status for both partnerships", %{partnership: partnership} do
      assert {:ok, updated} = Accounts.update_partnership_status(partnership, :active)
      assert updated.status == :active

      # Verify reverse partnership
      reverse = Repo.get_by(Partnership,
        user_id: partnership.partner_id,
        partner_id: partnership.user_id
      )
      assert reverse.status == :active
    end

    test "record_interaction/2 creates interaction and updates stats", %{partnership: partnership} do
      attrs = %{
        interaction_type: :message,
        content: %{text: "Hello!"}
      }

      assert {:ok, interaction} = Accounts.record_interaction(partnership.id, attrs)
      assert interaction.interaction_type == :message

      # Verify stats were updated
      updated_partnership = Repo.get(Partnership, partnership.id)
      assert updated_partnership.interaction_count == 1
      assert updated_partnership.last_interaction_date == Date.utc_today()
      assert updated_partnership.stats["monthly_activity"] != %{}
    end
  end

  describe "partnership interaction recording" do
    setup do
      partnership = insert(:partnership, status: :active)
      %{
        partnership: partnership,
        user: Repo.get!(User, partnership.user_id)
      }
    end

    test "record_interaction/2 creates interaction and updates stats", %{partnership: partnership, user: user} do
      attrs = %{
        interaction_type: :message,
        content: %{text: "Hello!"}
      }

      assert {:ok, interaction} = Accounts.record_interaction(partnership.id, attrs)
      assert interaction.interaction_type == :message
      assert interaction.content["text"] == "Hello!"

      updated_user = Repo.get(User, user.id)
      assert updated_user.interaction_count == 1
      assert updated_user.stats["total_interactions"] == 1
    end

    test "record_interaction/2 with invalid interaction type returns error", %{partnership: partnership} do
      attrs = %{
        interaction_type: :invalid_type,
        content: %{text: "Hello!"}
      }

      assert {:error, changeset} = Accounts.record_interaction(partnership.id, attrs)
      assert "is invalid" in errors_on(changeset).interaction_type
    end

    test "record_interaction/2 with missing content returns error", %{partnership: partnership} do
      attrs = %{interaction_type: :message}

      assert {:error, changeset} = Accounts.record_interaction(partnership.id, attrs)
      assert "can't be blank" in errors_on(changeset).content
    end
  end

  describe "partnership achievements" do
    setup do
      {:ok, partnership} = Accounts.create_partnership(%{
        user_id: insert(:user).id,
        partner_id: insert(:user).id,
        status: :active
      })
      %{partnership: partnership}
    end

    test "achievements are granted for interaction milestones", %{partnership: partnership} do
      # Create multiple interactions to trigger achievement
      Enum.each(1..100, fn _ ->
        {:ok, _} = Accounts.record_interaction(partnership.id, %{
          interaction_type: :message,
          content: %{text: "Hello!"}
        })
      end)

      updated_user = Repo.get(User, partnership.user_id) |> Repo.preload(:achievements)
      assert Enum.any?(updated_user.achievements, & &1.achievement_type == "hundred_interactions")
    end

    test "achievements update user points", %{partnership: partnership, user: user} do
      initial_points = user.points

      {:ok, _} = Accounts.record_interaction(partnership.id, %{
        interaction_type: :message,
        content: %{text: "First message!"}
      })

      updated_user = Repo.get(User, user.id)
      assert updated_user.points > initial_points
    end
  end

  describe "streak calculations" do
    setup do
      partnership = insert(:partnership, status: :active, streak_days: 0)
      %{partnership: partnership}
    end

    test "maintains streak for consecutive day interactions", %{partnership: partnership} do
      base_time = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create interactions for past 7 days
      Enum.each(0..6, fn days_ago ->
        interaction_time = DateTime.add(base_time, -days_ago * 86400, :second)

        {:ok, _} = Accounts.record_interaction(partnership.id, %{
          interaction_type: :message,
          content: %{text: "Day #{days_ago}"},
          inserted_at: interaction_time
        })
      end)

      updated_partnership = Repo.get(Partnership, partnership.id)
      assert updated_partnership.streak_days == 7
    end

    test "breaks streak for missed day", %{partnership: partnership} do
      base_time = DateTime.utc_now() |> DateTime.truncate(:second)

      # Today's interaction
      {:ok, _} = Accounts.record_interaction(
        partnership.id,
        %{
          interaction_type: :message,
          content: %{text: "Today"},
          inserted_at: base_time
        }
      )

      # Interaction from 2 days ago
      {:ok, _} = Accounts.record_interaction(
        partnership.id,
        %{
          interaction_type: :message,
          content: %{text: "Two days ago"},
          inserted_at: DateTime.add(base_time, -2 * 86400, :second)
        }
      )

      updated_partnership = Repo.get(Partnership, partnership.id)
      assert updated_partnership.streak_days == 1
    end

    test "updates longest_streak when surpassing previous record", %{partnership: partnership} do
      base_time = DateTime.utc_now() |> DateTime.truncate(:second)

      # Update longest_streak
      {:ok, _} = Repo.update(Partnership.changeset(partnership, %{longest_streak: 5}))

      # Create interactions for past 7 days
      Enum.each(0..6, fn days_ago ->
        interaction_time = DateTime.add(base_time, -days_ago * 86400, :second)

        attrs = %{
          interaction_type: :message,
          content: %{text: "Day #{days_ago}"},
          inserted_at: interaction_time
        }

        {:ok, _} = Accounts.record_interaction(partnership.id, attrs)
      end)

      updated_partnership = Repo.get(Partnership, partnership.id)
      assert updated_partnership.longest_streak == 7
    end
  end

  describe "partnership statistics" do
    setup do
      partnership = insert(:partnership, status: :active)
      %{partnership: partnership}
    end

    test "get_partnership_stats/1 handles empty partnerships", %{partnership: partnership} do
      stats = Accounts.get_partnership_stats(partnership.id)

      assert stats.total_interactions == 0
      assert stats.streak_days == 0
      assert stats.longest_streak == 0
      assert map_size(stats.interactions) == 0
      assert stats.days_connected >= 0
    end
  end
end
