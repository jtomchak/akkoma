defmodule Pleroma.Docs.JSON do
  @behaviour Pleroma.Docs.Generator
  @external_resource "config/description.exs"
  @raw_config Pleroma.Config.Loader.read("config/description.exs")
  @raw_descriptions @raw_config[:pleroma][:config_description]
  @term __MODULE__.Compiled

  @spec compile :: :ok
  def compile do
    :persistent_term.put(@term, Pleroma.Docs.Generator.convert_to_strings(@raw_descriptions))
  end

  @spec compiled_descriptions :: Map.t()
  def compiled_descriptions do
    :persistent_term.get(@term)
  end

  @spec process(keyword()) :: {:ok, String.t()}
  def process(descriptions) do
    with path <- "docs/generated_config.json",
         {:ok, file} <- File.open(path, [:write, :utf8]),
         formatted_descriptions <-
           Pleroma.Docs.Generator.convert_to_strings(descriptions),
         json <- Jason.encode!(formatted_descriptions),
         :ok <- IO.write(file, json),
         :ok <- File.close(file) do
      {:ok, path}
    end
  end
end
