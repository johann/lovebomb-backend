# test/lovebomb_web/controllers/error_json_test.exs
defmodule LovebombWeb.ErrorJSONTest do
  use LovebombWeb.ConnCase, async: true

  test "renders 404" do
    assert LovebombWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert LovebombWeb.ErrorJSON.render("500.json", %{}) == %{errors: %{detail: "Internal Server Error"}}
  end

  test "renders 401" do
    assert LovebombWeb.ErrorJSON.render("401.json", %{}) == %{errors: %{detail: "Unauthorized"}}
  end

  test "renders 403" do
    assert LovebombWeb.ErrorJSON.render("403.json", %{}) == %{errors: %{detail: "Forbidden"}}
  end

  test "renders 422 with changeset errors" do
    changeset = %Ecto.Changeset{
      action: :insert,
      errors: [title: {"can't be blank", [validation: :required]}],
      data: %{},
      valid?: false
    }

    result = LovebombWeb.ErrorJSON.render("422.json", %{changeset: changeset})
    assert %{errors: %{detail: "Unprocessable Entity"}} = result
    assert %{errors: %{fields: %{title: ["can't be blank"]}}} = result
  end
end
