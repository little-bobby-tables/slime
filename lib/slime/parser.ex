defmodule Slime.Parser do
  @moduledoc """
  Build a Slime tree from a Slime document.
  """

  alias Slime.Parser.Preprocessor
  alias Slime.Parser.Nodes.EExNode
  alias Slime.TemplateSyntaxError

  def parse(""), do: []
  def parse(input) do
    indented_input = Preprocessor.indent(input)
    case :slime_parser.parse(indented_input) do
      {:fail, error} -> handle_syntax_error(input, indented_input, error)
      tokens -> tokens
    end
  end

  defp handle_syntax_error(input, indented_input, error) do
    {_reason, error, {{:line, line}, {:column, column}}} = error
    indented_line = indented_input |> String.split("\n") |> Enum.at(line - 1)
    input_line = input |> String.split("\n") |> Enum.at(line - 1)
    indent = Preprocessor.indent_meta_symbol
    column = case indented_line do
      <<^indent::binary-size(1), _::binary>> -> column - 1
      _ -> column
    end
    raise TemplateSyntaxError,
      line: input_line,
      message: inspect(error),
      line_number: line,
      column: column
  end

  r = ~r/(^|\G)(?:\\.|[^#]|#(?!\{)|(?<pn>#\{(?:[^"\}]++|"(?:\\.|[^"#]|#(?!\{)|(?&pn))*")*\}))*?\K"/u
  @quote_outside_interpolation_regex r

  def parse_eex_string(input) do
    if String.contains?(input, "\#{") do
      eex = ~s("#{String.replace(input, @quote_outside_interpolation_regex, ~S(\\"))}")
      %EExNode{content: eex, output: true}
    else
      input
    end
  end
end
