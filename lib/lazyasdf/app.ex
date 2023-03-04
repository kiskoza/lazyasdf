defmodule Lazyasdf.App do
  @behaviour Ratatouille.App

  alias Ratatouille.Runtime.Command
  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]

  alias Lazyasdf.Pane.Plugins
  alias Lazyasdf.Pane.Versions
  alias Lazyasdf.Asdf

  @arrow_left key(:arrow_left)
  @arrow_right key(:arrow_right)

  defmodule Model do
    defstruct [:height, :width, :plugins, :versions, selected_pane: :plugins]
  end

  alias __MODULE__.Model

  def init(%{window: %{height: h, width: w}}) do
    {plugin_state, _} = Plugins.init()
    {version_state, commands} = Versions.init(plugin_state.list)

    {%Model{
       height: h,
       width: w,
       selected_pane: :plugins,
       plugins: plugin_state,
       versions: version_state
     }, Command.batch(commands)}
  end

  def update(%Model{} = model, msg) do
    new_model =
      case {model.selected_pane, msg} do
        {_, {:event, %{ch: ch, key: key}}} when ch == ?h or key == @arrow_left ->
          put_in(model.selected_pane, :plugins)

        {_, {:event, %{ch: ch, key: key}}} when ch == ?l or key == @arrow_right ->
          put_in(model.selected_pane, :versions)

        {_, {{:refresh, plugin}, versions}} ->
          put_in(model.versions[plugin].items, versions)

        {_, {{:installed, plugin}, versions}} ->
          put_in(model.versions[plugin].installed, versions)

        {_, {{:install_finished, plugin}, :ok}} ->
          command = Command.new(fn -> Asdf.list(plugin) end, {:installed, plugin})

          {model, command}

        {:plugins, msg} ->
          pmodel = Plugins.update(model.plugins, msg)

          put_in(model.plugins, pmodel)

        {:versions, msg} ->
          case Versions.update(Plugins.selected(model.plugins), model.versions, msg) do
            {vmodel, command} ->
              {put_in(model.versions, vmodel), command}

            vmodel ->
              put_in(model.versions, vmodel)
          end

        _ ->
          model
      end

    new_model
  end

  def render(model) do
    view do
      row do
        column size: 6 do
          Plugins.render(model.selected_pane == :plugins, model.plugins, model)
        end

        column size: 6 do
          Versions.render(model.selected_pane == :versions, model.versions, model)
        end
      end
    end
  end
end
