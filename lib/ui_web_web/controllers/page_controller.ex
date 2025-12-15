defmodule UiWebWeb.PageController do
  use UiWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
