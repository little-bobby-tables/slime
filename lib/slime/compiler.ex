defmodule Slime.Compiler do
  @moduledoc """
  Compile a tree of parsed Slime into EEx.
  """

  alias Slime.Parser.Nodes.HTMLNode
  alias Slime.Parser.Nodes.EExNode
  alias Slime.Parser.Nodes.VerbatimTextNode
  alias Slime.Parser.Nodes.HTMLCommentNode
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
        true -> to_string(value)
      end

      ~s( #{to_string(name)}="#{value}")
    end
  end

  defp render(%DoctypeNode{content: text}), do: text
  defp render(%VerbatimTextNode{content: content}) do
    Enum.map(content, &render(&1))
  end
  defp render(%HTMLNode{name: name, spaces: spaces} = node) do
    attrs = Enum.map(node.attributes, &render_attribute/1)

    body = cond do
      node.closed            -> "<" <> Enum.join([name | attrs]) <> "/>"
      name in @void_elements -> "<" <> Enum.join([name | attrs]) <> ">"
      true                   -> "<" <> Enum.join([name | attrs]) <> ">"
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
  defp render(raw), do: raw

  defp leading_space(%{leading: true}), do: " "
  defp leading_space(_), do: ""

  defp trailing_space(%{trailing: true}), do: " "
  defp trailing_space(_), do: ""

  # defp render_branch(%{} = branch) do
  #   opening =
  #     branch.attributes
  #     |> Enum.map(fn {k, v} -> render_attribute(k, v) end)
  #     |> Enum.join
  #     |> open(branch)
  #   closing = close(branch)
  #   opening <> compile(branch.children) <> closing
  # end
  #
  # defp open(_, %EExNode{content: code, attributes: attrs, spaces: spaces}) do
  #   prefix = if spaces[:leading], do: " "
  #   suffix = if spaces[:trailing], do: " "
  #   inline = if attrs[:inline], do: "=", else: ""
  #   "#{prefix}<%#{inline} #{code} %>#{suffix}\r"
  # end
  # defp open(_, %HTMLNode{tag: :html_comment}) do
  #   "<!--"
  # end
  # defp open(_, %HTMLNode{tag: :ie_comment, content: conditions}) do
  #   "<!--[#{conditions}]>"
  # end
  # defp open(attrs, %HTMLNode{tag: tag, spaces: spaces, close: close}) do
  #   prefix = if spaces[:leading], do: " "
  #   suffix = if close, do: "/"
  #   tag    = String.rstrip("#{tag}#{attrs}")
  #   "#{prefix}<#{tag}#{suffix}>"
  # end
  #
  # defp close(%HTMLNode{tag: tag, spaces: spaces}) when tag in @void_elements do
  #   if spaces[:trailing] do
  #     " "
  #   else
  #     ""
  #   end
  # end
  # defp close(%HTMLNode{tag: :html_comment}) do
  #   "-->"
  # end
  # defp close(%HTMLNode{tag: :ie_comment}) do
  #   "<![endif]-->"
  # end
  # defp close(%EExNode{content: code}) do
  #   if Regex.match?(~r/(fn.*->| do)\s*$/, code) do
  #     "<% end %>"
  #   else
  #     ""
  #   end
  # end
  # defp close(%HTMLNode{tag: tag, spaces: spaces}) do
  #   "</#{tag}>#{if spaces[:trailing], do: " "}"
  # end
end
