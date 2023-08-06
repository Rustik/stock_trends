defmodule StockTrendsWeb.TrendsLive do
  use StockTrendsWeb, :live_view

  alias StockTrends.TrendQuery
  alias StockTrends.LinkPuller

  def mount(_params, _session, socket) do
    if connected?(socket), do: check_data_and_run_puller()
    {:ok, socket, temporary_assigns: [trends: [], type: "long", updated_at: nil]}
  end

  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    per_page = String.to_integer(params["per_page"] || "20")

    sort_by = (params["sort_by"] || "id") |> String.to_atom()
    sort_order = (params["sort_order"] || "asc") |> String.to_atom()

    type = (params["type"] || "long")
    type_options = %{type: type}

    date = (params["date"] || (Date.utc_today |> Date.to_string()))
    date_options = %{date: date}

    trends_count = TrendQuery.count(
      type: type,
      date: date
    )

    pages_count = if trends_count > per_page, do: ceil(trends_count/per_page), else: 1

    paginate_options = %{page: page, per_page: per_page, pages_count: pages_count}
    sort_options = %{sort_by: sort_by, sort_order: sort_order}

    trends =
      TrendQuery.list_trends(
        paginate: paginate_options,
        sort: sort_options,
        type: type,
        date: date
      )

    socket =
      assign(socket,
        options: Map.merge(Map.merge(Map.merge(paginate_options, sort_options), type_options), date_options),
        trends: trends,
        updated_at: last_updated_at(date, type),
        last_pull_info: last_pull_info()
      )

    {:noreply, socket}
  end

  def handle_event("filter", %{"type" => type}, socket) do
    socket =
      push_patch(socket,
        to:
          Routes.live_path(
            socket,
            __MODULE__,
            page: 1,
            per_page: socket.assigns.options.per_page,
            sort_by: socket.assigns.options.sort_by,
            sort_order: socket.assigns.options.sort_order,
            type: type,
            date: socket.assigns.options.date
          )
      )

    {:noreply, socket}
  end

  def handle_info(:update_puller_info, socket) do
    IO.puts("puller running: #{ puller_running?() }")
    if puller_running?(), do: Process.send_after(self(), :update_puller_info, 1000)

    socket =
      push_patch(socket,
        to:
          Routes.live_path(
            socket,
            __MODULE__,
            page: socket.assigns.options.page,
            per_page: socket.assigns.options.per_page,
            sort_by: socket.assigns.options.sort_by,
            sort_order: socket.assigns.options.sort_order,
            type: socket.assigns.options.type,
            date: socket.assigns.options.date,
            last_pull_info: last_pull_info()
          )
      )

    {:noreply, socket}
  end

  # Not used currently
  def handle_event("select-per-page", %{"per-page" => per_page}, socket) do
    per_page = String.to_integer(per_page)

    socket =
      push_patch(socket,
        to:
          Routes.live_path(
            socket,
            __MODULE__,
            page: socket.assigns.options.page,
            per_page: per_page,
            sort_by: socket.assigns.options.sort_by,
            sort_order: socket.assigns.options.sort_order,
            type: socket.assigns.options.type,
            date: socket.assigns.options.date
          )
      )

    {:noreply, socket}
  end

  defp last_pull_info do
    info = LinkPuller.info()
    Map.drop(info, [:industry_earnings_pe_ivv])
  end

  defp check_data_and_run_puller do
    if no_data_for_today?() and not puller_running?(), do: pull(), else: nil
  end

  defp no_data_for_today? do
    TrendQuery.count(date: Date.utc_today) == 0
  end

  defp puller_running? do
    LinkPuller.puller_running?
  end

  defp pull do
    LinkPuller.perform()
    Process.send_after(self(), :update_puller_info, 1000)
  end

  defp pagination_link(socket, text, page, options, class) do
    live_patch(text,
      to:
        Routes.live_path(
          socket,
          __MODULE__,
          page: page,
          per_page: options.per_page,
          sort_by: options.sort_by,
          sort_order: options.sort_order,
          type: options.type,
          date: options.date
        ),
      class: class
    )
  end

  defp sort_link(socket, text, sort_by, options) do
    text =
      if sort_by == options.sort_by do
        text <> emoji(options.sort_order)
      else
        text
      end

    live_patch(text,
      to:
        Routes.live_path(
          socket,
          __MODULE__,
          sort_by: sort_by,
          sort_order: toggle_sort_order(options.sort_order),
          page: options.page,
          per_page: options.per_page,
          type: options.type,
          date: options.date
        )
    )
  end

  defp type_options do
    [
      "Шорты": "short",
      "Лонги": "long"
    ]
  end

  defp last_updated_at(date, type) do
    TrendQuery.last_updated_at(
      type: type,
      date: date
    )
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(:desc), do: :asc

  defp emoji(:asc), do: "👇"
  defp emoji(:desc), do: "👆"
end
