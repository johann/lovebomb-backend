defmodule LovebombWeb.ErrorJSONTest do
  use LovebombWeb.ConnCase, async: true

  test "renders 404" do
    assert LovebombWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert LovebombWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
