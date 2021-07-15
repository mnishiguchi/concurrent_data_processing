defmodule Airports do
  @moduledoc """

  ## Examples

      :timer.tc(Airports, :list_open_airports, [:enum])  |> elem(0) |> div(1000)
      :timer.tc(Airports, :list_open_airports, [:stream]) |> elem(0) |> div(1000)
      :timer.tc(Airports, :list_open_airports, [:concurrent]) |> elem(0) |> div(1000)

  """
  # https://hexdocs.pm/nimble_csv/NimbleCSV.html
  alias NimbleCSV.RFC4180, as: CSV

  def airports_csv_path() do
    Application.app_dir(:concurrent_data_processing, "/priv/airports.csv")
  end

  def list_open_airports(:enum) do
    airports_csv_path()
    |> File.read!()
    |> CSV.parse_string()
    |> Enum.map(fn row ->
      %{
        id: Enum.at(row, 0),
        type: Enum.at(row, 2),
        name: Enum.at(row, 3),
        country: Enum.at(row, 8)
      }
    end)
    |> Enum.reject(&(&1.type == "closed"))
  end

  # inside `Stream.map/2`, `:binary.copy/1` is needed to copy the data from `parse_stream/1`. See
  # https://hexdocs.pm/nimble_csv/NimbleCSV.html#module-binary-references
  def list_open_airports(:stream) do
    airports_csv_path()
    |> File.stream!()
    |> CSV.parse_stream()
    |> Stream.map(fn row ->
      %{
        id: :binary.copy(Enum.at(row, 0)),
        type: :binary.copy(Enum.at(row, 2)),
        name: :binary.copy(Enum.at(row, 3)),
        country: :binary.copy(Enum.at(row, 8))
      }
    end)
    |> Stream.reject(&(&1.type == "closed"))
    |> Enum.to_list()
  end

  # We need `skip_headers: false` option because we parse each row individually, rather than the whole file.
  def list_open_airports(:concurrent) do
    airports_csv_path()
    |> File.stream!()
    |> Flow.from_enumerable()
    |> Flow.map(fn row ->
      [row] = CSV.parse_string(row, skip_headers: false)

      %{
        id: Enum.at(row, 0),
        type: Enum.at(row, 2),
        name: Enum.at(row, 3),
        country: Enum.at(row, 8)
      }
    end)
    |> Flow.reject(&(&1.type == "closed"))
    |> Enum.to_list()
  end

  # This is a bad example. The result will contain duplicate country keys.
  def list_open_airports(:concurrent_reduce_without_partition) do
    airports_csv_path()
    |> File.stream!()
    |> Flow.from_enumerable()
    |> Flow.map(fn row ->
      [row] = CSV.parse_string(row, skip_headers: false)

      %{
        id: Enum.at(row, 0),
        type: Enum.at(row, 2),
        name: Enum.at(row, 3),
        country: Enum.at(row, 8)
      }
    end)
    |> Flow.reject(&(&1.type == "closed"))
    |> Flow.reduce(fn -> %{} end, fn item, acc -> Map.update(acc, item.country, 1, &(&1 + 1)) end)
    |> Enum.to_list()
  end

  # There will be no duplicate country keys because the Flow is now partitioned by country value.
  def list_open_airports(:concurrent_reduce_with_partition) do
    airports_csv_path()
    |> File.stream!()
    |> Flow.from_enumerable()
    |> Flow.map(fn row ->
      [row] = CSV.parse_string(row, skip_headers: false)

      %{
        id: Enum.at(row, 0),
        type: Enum.at(row, 2),
        name: Enum.at(row, 3),
        country: Enum.at(row, 8)
      }
    end)
    |> Flow.reject(&(&1.type == "closed"))
    |> Flow.partition(key: {:key, :country})
    |> Flow.reduce(fn -> %{} end, fn item, acc -> Map.update(acc, item.country, 1, &(&1 + 1)) end)
    |> Enum.to_list()
  end

  def list_open_airports(:concurrent_group_with_partition) do
    airports_csv_path()
    |> File.stream!()
    |> Flow.from_enumerable()
    |> Flow.map(fn row ->
      [row] = CSV.parse_string(row, skip_headers: false)

      %{
        id: Enum.at(row, 0),
        type: Enum.at(row, 2),
        name: Enum.at(row, 3),
        country: Enum.at(row, 8)
      }
    end)
    |> Flow.reject(&(&1.type == "closed"))
    |> Flow.partition(key: {:key, :country})
    |> Flow.group_by(& &1.country)
    |> Flow.map(fn {country, data} -> {country, Enum.count(data)} end)
    |> Enum.to_list()
  end

  # Sort by value in decending order and take 10 entries using `Flow.take_sort/3`.
  def list_open_airports(:concurrent_group_with_partition_top_ten) do
    airports_csv_path()
    |> File.stream!()
    |> Flow.from_enumerable()
    |> Flow.map(fn row ->
      [row] = CSV.parse_string(row, skip_headers: false)

      %{
        id: Enum.at(row, 0),
        type: Enum.at(row, 2),
        name: Enum.at(row, 3),
        country: Enum.at(row, 8)
      }
    end)
    |> Flow.reject(&(&1.type == "closed"))
    |> Flow.partition(key: {:key, :country})
    |> Flow.group_by(& &1.country)
    |> Flow.map(fn {country, data} -> {country, Enum.count(data)} end)
    |> Flow.take_sort(10, fn {_, a}, {_, b} -> a > b end)
    |> Enum.to_list()
    |> List.flatten()
  end

  # Capture progress snapshots every 1000 events.
  def list_open_airports(:concurrent_group_with_window_and_trigger) do
    airports_csv_path()
    |> File.stream!()
    |> Stream.map(fn event ->
      # Intentionally slow down the file stream events by using Process.sleep/1
      Process.sleep(Enum.random([0, 0, 0, 1]))
      event
    end)
    |> Flow.from_enumerable()
    |> Flow.map(fn row ->
      [row] = CSV.parse_string(row, skip_headers: false)

      %{
        id: Enum.at(row, 0),
        type: Enum.at(row, 2),
        name: Enum.at(row, 3),
        country: Enum.at(row, 8)
      }
    end)
    |> Flow.reject(&(&1.type == "closed"))
    |> Flow.partition(
      window: Flow.Window.trigger_every(Flow.Window.global(), 1000),
      key: {:key, :country}
    )
    |> Flow.group_by(& &1.country)
    |> Flow.on_trigger(fn acc, _partition_info, {_type, _id, trigger} = _window_info ->
      # Within the callback function, we have the opportunity to use the snapshot data. For example,
      # persist the events to database or send them elsewhere for processing.

      # Show progress in IEx, or use the data for something else.
      events =
        acc
        |> Enum.map(fn {country, data} -> {country, Enum.count(data)} end)
        |> IO.inspect(label: inspect(self()))

      case trigger do
        :done -> {events, acc}
        {:every, 1000} -> {[], acc}
      end
    end)
    |> Enum.sort(fn {_, a}, {_, b} -> a > b end)
    |> Enum.take(10)
  end

  def list_open_airports(:concurrent_group_with_window_and_trigger_departition) do
    airports_csv_path()
    |> File.stream!()
    |> Stream.map(fn event ->
      # Intentionally slow down the file stream events by using Process.sleep/1
      Process.sleep(Enum.random([0, 0, 0, 1]))
      event
    end)
    |> Flow.from_enumerable()
    |> Flow.map(fn row ->
      [row] = CSV.parse_string(row, skip_headers: false)

      %{
        id: Enum.at(row, 0),
        type: Enum.at(row, 2),
        name: Enum.at(row, 3),
        country: Enum.at(row, 8)
      }
    end)
    |> Flow.reject(&(&1.type == "closed"))
    |> Flow.partition(
      window: Flow.Window.trigger_every(Flow.Window.global(), 1000),
      key: {:key, :country}
    )
    |> Flow.group_by(& &1.country)
    |> Flow.on_trigger(fn acc, _partition_info, {_type, _id, trigger} = _window_info ->
      # Within the callback function, we have the opportunity to use the snapshot data. For example,
      # persist the events to database or send them elsewhere for processing.

      # Show progress in IEx, or use the data for something else.
      events =
        acc
        |> Enum.map(fn {country, data} -> {country, Enum.count(data)} end)
        |> IO.inspect(label: inspect(self()))

      case trigger do
        :done -> {events, acc}
        {:every, 1000} -> {[], acc}
      end
    end)
    # departition(flow, acc_fun, merge_fun, done_fun, options \\ [])
    # https://hexdocs.pm/flow/Flow.html#departition/5
    |> Flow.departition(
      _acc_fun = fn ->
        _initial_acc = []
      end,
      _merger_fun = fn partition_state, acc when is_tuple(partition_state) and is_list(acc) ->
        [partition_state] ++ acc
      end,
      _done_fun = fn final_acc ->
        # Top ten for each partition
        final_acc
        |> List.flatten()
        |> Enum.sort(fn {_, a}, {_, b} -> a > b end)
        |> Enum.take(10)
      end
    )
    |> Enum.to_list()
    # Top ten for the entire window
    |> List.flatten()
    |> Enum.sort(fn {_, a}, {_, b} -> a > b end)
    |> Enum.take(10)
  end
end
