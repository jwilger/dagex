defmodule Dagex.ErrorHelpers do
  @moduledoc false

  @doc """
  A helper that transforms changeset errors into a map of messages.

  assert {:error, changeset} = Accounts.create_user(%{password: "short"})
  assert "password is too short" in errors_on(changeset).password
  assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  @spec errors_on(Ecto.Changeset.t()) :: %{optional(atom) => list(String.t())}
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _full_match, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  A helper that gets errors for a specific changeset field

  Unlike calling `errors_on(changeset).my_field`, this does not raise a
  `KeyError` if the field has no errors; it instead returns an empty list.
  """
  @spec errors_on(Ecto.Changeset.t(), atom()) :: list(String.t())
  def errors_on(changeset, field) do
    Map.get(errors_on(changeset), field, [])
  end
end
