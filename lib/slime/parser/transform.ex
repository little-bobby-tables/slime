defmodule Slime.Parser.Transform do
  @moduledoc """
  PEG parser callbacks module.
  Define transformations from parsed iolist to ast.
  See https://github.com/seancribbs/neotoma/wiki#working-with-the-ast
  """

  require IEx

  import Slime.Parser.Preprocessor, only: [indent_size: 1]
  alias Slime.Parser.AttributesKeyword
  alias Slime.Parser.EmbeddedEngine
  alias Slime.Parser.TextBlock

  alias Slime.Parser.Nodes.{
    HTMLNode, EExNode, VerbatimTextNode,
    HTMLCommentNode, InlineHTMLNode, DoctypeNode
  }

  @default_tag Application.get_env(:slime, :default_tag, "div")
  @sort_attrs Application.get_env(:slime, :sort_attrs, true)
  @merge_attrs Application.get_env(:slime, :merge_attrs, %{"class" => " "})
  @shortcut Application.get_env(:slime, :shortcut, %{
    "." => %{attr: "class"},
    "#" => %{attr: "id"}
  })

  # TODO: separate dynamic elixir blocks by parser
  @quote_outside_interpolation_regex ~r/(^|\G)(?:\\.|[^#]|#(?!\{)|(?<pn>#\{(?:[^"}]++|"(?:\\.|[^"#]|#(?!\{)|(?&pn))*")*\}))*?\K"/u

  @type ast :: term
  @type index :: {{:line, non_neg_integer}, {:column, non_neg_integer}}

  @spec transform(atom, iolist, index) :: ast
  def transform(:document, input, _index) do
    case input do
      [[], tags | _] -> tags
      [doctype, [""] | _] -> [doctype]
      [doctype, tags | _] -> [doctype | tags]
    end
  end

  def transform(:doctype, input, _index) do
    %DoctypeNode{name: to_string(input[:name])}
  end

  def transform(:tag, [tag, _], _index), do: tag

  def transform(:tag_item, [_, tag], _index), do: tag

  def transform(:simple_tag, input, _index) do
    {tag_name, shorthand_attrs} = input[:tag]
    {attrs, inline_content, is_closed} = input[:content]
    children = inline_content ++ input[:children]

    attributes =
      shorthand_attrs
      |> Enum.concat(attrs)
      |> AttributesKeyword.merge(@merge_attrs)

    attributes = if @sort_attrs do
      Enum.sort_by(attributes, fn ({key, _value}) -> key end)
    else
      attributes
    end

    %HTMLNode{
      name: tag_name,
      attributes: attributes,
      spaces: input[:spaces],
      closed: is_closed,
      children: children
    }
  end

  def transform(:nested_tags, input, _index), do: input[:children]

  def transform(:html_comment, input, _index) do
    indent = indent_size(input[:indent])
    decl_indent = indent + String.length(input[:type])

    %HTMLCommentNode{
      content: TextBlock.render_content(input[:content], decl_indent)
    }
  end

  def transform(:code_comment, _input, _index), do: ""

  def transform(:verbatim_text, input, _index) do
    indent = indent_size(input[:indent])
    decl_indent = indent + String.length(input[:type])
    content = TextBlock.render_content(input[:content], decl_indent)
    content = if input[:type] == "'", do: content ++ [" "], else: content

    %VerbatimTextNode{content: content}
  end

  def transform(:text_block, input, _index) do
    case input do
      [line, []] -> [line]
      [line, nested_lines] -> [line | nested_lines[:lines]]
    end
  end

  def transform(:text_block_nested_lines, input, _index) do
    case input do
      [line, []] -> [line]
      [line, nested_lines] ->
        [line | Enum.flat_map(nested_lines, fn([_crlf, l]) ->
          case l do
            [_indent, nested, _dedent] -> nested
            nested -> nested
          end
        end)]
    end
  end

  def transform(:text_block_line, input, _index) do
    [space, line] = input
    indent = indent_size(space)
    case line do
      {:simple, content} -> {indent, to_string(content), false}
      {:dynamic, content} -> {indent, to_string(content), true}
    end
  end

  def transform(:embedded_engine, [engine, _, lines], _index) do
    lines = case lines do
      {:empty, _} -> ""
      _ -> List.flatten(lines[:lines])
    end
    case EmbeddedEngine.render_with_engine(engine, lines) do
      {tag, content} -> %HTMLNode{name: tag,
        attributes: (content[:attributes] || []),
        children: content[:children]}
      node -> node
    end
  end

  def transform(:embedded_engine_lines, input, _index) do
    [line, rest] = input
    lines = Enum.map(rest, fn ([_, lines]) -> lines end)
    [line | lines]
  end

  def transform(:embedded_engine_line, input, _index) do
    to_string(input)
  end

  def transform(:inline_html, [_, content, children], _index) do
    %InlineHTMLNode{content: [content], children: children}
  end

  def transform(:code, input, _index) do
    {output, spaces} = case input[:output] do
      "-" -> {false, %{}}
      [_, _, spaces] -> {true, spaces}
    end

    %EExNode{
      content: input[:code],
      output: output,
      spaces: spaces,
      children: input[:children] ++ input[:optional_else]
    }
  end

  def transform(:code_else_condition, input, _index) do
    [%EExNode{content: "else", children: input[:children]}]
  end

  def transform(:code_lines, input, _index) do
    case input do
      [code_line, crlf, [_, lines, _]] -> code_line <> crlf <> lines
      [code_line, crlf, line] -> code_line <> crlf <> line
      line -> line
    end
  end

  def transform(:code_line, input, _index) do
    input |> to_string |> String.replace("\x0E", "")
  end

  def transform(:code_line_with_brake, input, _index) do
    input |> to_string |> String.replace("\x0E", "")
  end

  def transform(:inline_tag, input, _index) do
    {tag_name, initial_attrs} = input[:tag]

    %HTMLNode{
      name: tag_name,
      attributes: initial_attrs,
      spaces: input[:spaces],
      children: [input[:children]]
    }
  end

  def transform(:simple_tag_content_without_attrs, [_, content], _index), do: content

  def transform(:attributes_with_content, input, _index) do
    {attrs, content} = case input do
      [attrs, _, content] -> {attrs, content}
      content -> {[], content}
    end

    {inline_content, is_closed} = case content do
      "/" -> {[], true}
      "" -> {[], false}
      [] -> {[], false}
      (%EExNode{} = eex) -> {[eex], false}
      text -> {[%VerbatimTextNode{content: [text]}], false}
    end

    {attrs, inline_content, is_closed}
  end

  def transform(:text_content, input, _index) do
    case input do
      {:dynamic, content} ->
        %EExNode{content: content |> to_string |> wrap_in_quotes, output: true}
      {:simple, content} -> content
    end
  end

  def transform(:dynamic_content, input, _index) do
    content = input |> Enum.at(3) |> to_string
    %EExNode{content: content, output: true}
  end

  def transform(:tag_spaces, input, _index) do
    leading = input[:leading]
    trailing = input[:trailing]
    case {leading, trailing} do
      {"<", ">"} ->  %{leading: true, trailing: true}
      {"<", _} ->  %{leading: true}
      {_, ">"} ->  %{trailing: true}
      _ -> %{}
    end
  end

  def transform(:tag_shortcut, input, _index) do
    {tag, attrs} = case input do
      {:tag, value} -> {value, []}
      {:attrs, value} -> {@default_tag, value}
      list -> {list[:tag], list[:attrs]}
    end
    {tag_name, initial_attrs} = expand_tag_shortcut(tag)
    {tag_name, Enum.concat(initial_attrs, attrs)}
  end

  def transform(:shortcuts, input, _index) do
    Enum.concat([input[:head] | input[:tail]])
  end

  def transform(:shortcut, input, _index) do
    {nil, attrs} = expand_attr_shortcut(input[:type], input[:value])
    attrs
  end

  def transform(:wrapped_attributes, input, _index), do: Enum.at(input, 1)

  def transform(:wrapped_attributes_list, input, _index) do
    head = input[:head]
    tail = Enum.map(input[:tail] || [[]], &List.last/1)
    [head | tail]
  end

  def transform(:wrapped_attribute, input, _index) do
    case input do
      {:attribute, attr} -> attr
      {:attribute_name, name} -> {name, true}
    end
  end

  def transform(:plain_attributes, input, _index) do
    head = input[:head]
    tail = Enum.map(input[:tail] || [[]], &List.last/1)
    [head | tail]
  end

  def transform(:attribute, [name, _, value], _index), do: {name, value}

  def transform(:attribute_value, input, _index) do
    case input do
      {:simple, [_, content, _]} -> to_string(content)
      {:dynamic, content} -> {:eex, to_string(content)}
    end
  end

  def transform(:text, input, _index), do: to_string(input)
  def transform(:tag_name, input, _index), do: to_string(input)
  def transform(:attribute_name, input, _index), do: to_string(input)
  def transform(:crlf, input, _index), do: to_string(input)
  def transform(_symdol, input, _index), do: input

  defp fix_indents(lines), do: lines |> Enum.reverse |> fix_indents(0, [])
  defp fix_indents([], _, result), do: result
  defp fix_indents([{0, ""} | rest], current, result) do
    fix_indents(rest, current, [{current, ""} | result])
  end
  defp fix_indents([{indent, _} = line | rest], _current, result) do
    fix_indents(rest, indent, [line | result])
  end

  def remove_empty_lines(lines) do
    Enum.filter(lines, fn
      ({0, ""}) -> false
      (_) -> true
    end)
  end

  def expand_tag_shortcut(tag) do
    case Map.fetch(@shortcut, tag) do
      :error -> {tag, []}
      {:ok, spec} -> expand_shortcut(spec, tag)
    end
  end

  def wrap_in_quotes(content) do
    ~s("#{String.replace(content, @quote_outside_interpolation_regex, ~S(\\"))}")
  end

  defp expand_attr_shortcut(type, value) do
    spec = Map.fetch!(@shortcut, type)
    expand_shortcut(spec, value)
  end

  def expand_shortcut(spec, value) do
    attrs = case spec[:attr] do
      nil -> []
      attr_names -> attr_names |> List.wrap |> Enum.map(&{&1, value})
    end

    final_attrs = Enum.concat(attrs, Map.get(spec, :additional_attrs, []))
    {spec[:tag], final_attrs}
  end
end
