if Code.ensure_loaded?(Saxy) do
  defmodule ExAws.SQS.SaxyCollector do
    @moduledoc false

    def build(path, [_ | _] = attrs) when is_list(path) do
      definition =
        path
        |> Enum.reverse()
        |> Enum.reduce(build_attrs(attrs, %{}), fn key, acc ->
          %{key => acc}
        end)

      {default_for(attrs), definition}
    end

    defp build_attrs(attrs, acc) do
      Enum.reduce(attrs, acc, fn {key, value}, acc ->
        unless is_atom(key) do
          raise ArgumentError, "attributes keys must be atoms, got: #{inspect(key)}"
        end

        unless is_list(value) do
          raise ArgumentError,
                "value for attribute #{inspect(key)} must be a list, got: #{inspect(value)}"
        end

        {path, trailing} = Enum.split_while(value, &is_binary/1)

        {type, trailing} =
          case trailing do
            [:many | trailing] -> {:many, trailing}
            _ -> {:one, trailing}
          end

        case trailing do
          [] -> build_path(path, {key, type, &__MODULE__.identity/1}, acc)
          [fun] when is_function(fun, 1) -> build_path(path, {key, type, fun}, acc)
          [_ | _] -> build_path(path, {key, type, default_for(trailing), trailing}, acc)
        end
      end)
    end

    defp default_for(trailing) do
      for {k, v} <- trailing, do: {k, if(:many in v, do: [], else: "")}, into: %{}
    end

    defp build_path([key], {attr, type, default, [_ | _] = attrs}, acc) do
      case acc do
        %{^key => current = %{}} ->
          Map.put(acc, key, {attr, type, default, build_attrs(attrs, current)})

        %{^key => _} ->
          raise ArgumentError,
                "cannot store node key #{inspect(key)} because it is already mapped to a text"

        %{} ->
          Map.put(acc, key, {attr, type, default, build_attrs(attrs, %{})})
      end
    end

    defp build_path([key], {attr, type, fun}, acc) do
      case acc do
        %{^key => %{}} ->
          raise ArgumentError,
                "cannot store text key #{inspect(key)} because it is expected to be a node"

        %{^key => _} ->
          raise ArgumentError,
                "cannot store text key #{inspect(key)} because it is already mapped to another text"

        %{} ->
          Map.put(acc, key, {attr, type, fun})
      end
    end

    defp build_path([key | keys], value, acc) do
      case acc do
        %{^key => %{} = nested} ->
          Map.put(acc, key, build_path(keys, value, nested))

        %{^key => _} ->
          raise ArgumentError,
                "cannot store node key #{inspect(key)} because it expected to be a text"

        %{} ->
          Map.put(acc, key, build_path(keys, value, %{}))
      end
    end

    def parse_string!(data, definition) when is_binary(data) do
      case Saxy.parse_string(data, __MODULE__, definition, []) do
        {:ok, value} -> value
        {:error, exception} -> raise exception
      end
    end

    @doc false
    def identity(value), do: value

    ## Saxy callbacks

    @behaviour Saxy.Handler

    @impl true
    def handle_event(:start_document, _prolog, {default, definition}) do
      {:ok, {default, [{"root", nil, definition}]}}
    end

    # When skipping

    def handle_event(:start_element, {_, _}, {:skip, counter, map_stack}) do
      {:ok, {:skip, counter + 1, map_stack}}
    end

    def handle_event(:characters, _characters, {:skip, counter, map_stack}) do
      {:ok, {:skip, counter, map_stack}}
    end

    def handle_event(:end_element, _tag, {:skip, 0, map_stack}) do
      {:ok, map_stack}
    end

    def handle_event(:end_element, _tag, {:skip, counter, map_stack}) do
      {:ok, {:skip, counter - 1, map_stack}}
    end

    # When collecting

    def handle_event(:start_element, {tag, _attributes}, {map, [{_, _, head} | _] = stack}) do
      map = maybe_reverse_map(map, tag)

      case head do
        %{^tag => %{} = next} ->
          {:ok, {map, [{tag, nil, next} | stack]}}

        %{^tag => {attr, type, transformer}} ->
          {:ok, {nil, [{tag, {attr, type, map}, transformer} | stack]}}

        %{^tag => {attr, type, default, next = %{}}} ->
          {:ok, {default, [{tag, {attr, type, map}, next} | stack]}}

        %{} ->
          {:ok, {:skip, 0, {map, stack}}}

        _ ->
          raise "expected node #{inspect(tag)} to be text"
      end
    end

    def handle_event(:characters, chars, {_, [{_, _, transformer} | _] = stack})
        when is_function(transformer) do
      {:ok, {transformer.(chars), stack}}
    end

    def handle_event(:characters, chars, {_, [{tag, _, _} | _]} = map_stack) do
      if String.trim_leading(chars) == "" do
        {:ok, map_stack}
      else
        raise "expected #{inspect(tag)} to be a node but it has text #{inspect(chars)}"
      end
    end

    def handle_event(:end_element, tag, {value, [{_, maybe_attr, _} | stack]}) do
      value = maybe_reverse_map(value, nil)

      map =
        case maybe_attr do
          # We store an annotated map that should be reversed if the starting tag does not match.
          {attr, :many, parent_map} ->
            {:reverse, tag, attr, Map.update(parent_map, attr, [value], &[value | &1])}

          {attr, :one, parent_map} ->
            Map.put(parent_map, attr, value)

          nil ->
            value
        end

      {:ok, {map, stack}}
    end

    def handle_event(:end_document, _, {map, _}) do
      {:ok, maybe_reverse_map(map, nil)}
    end

    defp maybe_reverse_map({:reverse, tag, _attr, map}, tag), do: map

    defp maybe_reverse_map({:reverse, _, attr, map}, _),
      do: Map.update!(map, attr, &Enum.reverse/1)

    defp maybe_reverse_map(map, _tag), do: map
  end
end
