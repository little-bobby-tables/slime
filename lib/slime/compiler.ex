defmodule Slime.Compiler do
  @moduledoc """
  Compile a tree of parsed Slime into EEx.
  """

  require IEx

  alias Slime.Doctype

  alias Slime.Parser.Nodes.HTMLNode
  alias Slime.Parser.Nodes.EExNode
  alias Slime.Parser.Nodes.VerbatimTextNode
  alias Slime.Parser.Nodes.HTMLCommentNode
  alias Slime.Parser.Nodes.InlineHTMLNode
  alias Slime.Parser.Nodes.DoctypeNode

  @void_elements ~w(
    area br col doctype embed hr img input link meta base param
    keygen source menuitem track wbr
  )

  def compile([]), do: ""
  def compile(tree) do
    lines_sep = if Application.get_env(:slime, :keep_lines), do: "\n", else: ""
    tree
    |> Enum.map(&render(&1))
    |> Enum.join(lines_sep)
    |> String.replace("\r", "")
  end

  defp render_attribute({_, []}), do: ""
  defp render_attribute({_, ""}), do: ""
  defp render_attribute({name, {:eex, content}}) do
    case content do
      "true"  -> " #{to_string(name)}"
      "false" -> ""
      "nil"   -> ""
      _ ->
       """
       <% slim__k = "#{to_string(name)}"; slim__v = #{content} %>\
       <%= if slim__v do %> <%= slim__k %><%= unless slim__v == true do %>\
       ="<%= slim__v %>"<% end %><% end %>\
       """
    end
  end
  defp render_attribute({name, value}) do
    if value == true do
      " #{to_string(name)}"
    else
      value = cond do
        is_binary(value) -> value
        is_list(value) -> Enum.join(value, " ")
        :otherwise -> to_string(value)
      end

      ~s( #{to_string(name)}="#{value}")
    end
  end

  defp render(%DoctypeNode{name: name}), do: Doctype.for(name)
  defp render(%VerbatimTextNode{content: content}), do: render(content)
  defp render(%HTMLNode{name: name, spaces: spaces} = node) do
    attrs = Enum.map(node.attributes, &render_attribute/1)
    tag_head = Enum.join([name | attrs])

    body = cond do
      node.closed            -> "<" <> tag_head <> "/>"
      name in @void_elements -> "<" <> tag_head <> ">"
      :otherwise             -> "<" <> tag_head <> ">"
        <> compile(node.children) <> "</" <> name <> ">"
    end

    leading_space(spaces) <> body <> trailing_space(spaces)
  end
  defp render(%EExNode{content: code, spaces: spaces, output: output} = node) do
    opening = (if output, do: "<%= ", else: "<% ") <> code <> " %>"
    closing = if Regex.match?(~r/(fn.*->| do)\s*$/, code) do
      "<% end %>"
    else
      ""
    end
    body = opening <> compile(node.children) <> closing

    leading_space(spaces) <> body <> trailing_space(spaces)
  end
  defp render(%InlineHTMLNode{content: content, children: children}) do
    render(content) <> compile(children)
  end
  defp render(%HTMLCommentNode{content: content}) do
    "<!--" <> render(content) <> "-->"
  end
  defp render([h | t]), do: [h | t] |> Enum.map(&render(&1)) |> Enum.join
  defp render(raw), do: raw

  defp leading_space(%{leading: true}), do: " "
  defp leading_space(_), do: ""

  defp trailing_space(%{trailing: true}), do: " "
  defp trailing_space(_), do: ""
end
