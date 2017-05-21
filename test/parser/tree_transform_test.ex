defmodule Slime.Parser.TreeTransformTest do
  use ExUnit.Case, async: true

  import Slime.Parser, only: [parse: 1]
  alias Slime.Tree.Nodes.HTMLNode
  alias Slime.Tree.Nodes.EExNode
  alias Slime.Tree.Nodes.VerbatimTextNode
  alias Slime.Tree.Nodes.HTMLCommentNode

  test "inline tags" do
    slime = """
    span.class: p#id
    """
    assert parse(slime) == [
      %HTMLNode{name: "span", attributes: [{"class", "class"}], children: [
        %HTMLNode{name: "p", attributes: [{"id", "id"}]}
      ]}
    ]
  end

  test "nested tags with blank lines" do
    slime = """
    div


    div


      p

        span

      p
    div
    """
    assert parse(slime) == [
      %HTMLNode{name: "div"},
      %HTMLNode{name: "div", children: [
        %HTMLNode{name: "p", children: [%HTMLNode{name: "span"}]},
        %HTMLNode{name: "p"}
      ]},
      %HTMLNode{name: "div"}
    ]
  end

  test "attributes" do
    slime = """
    div.class some-attr="value"
      p#id(wrapped-attr="value" another-attr="value")
    """
    assert parse(slime) == [
      %HTMLNode{name: "div", attributes: [
          {"class", "class"}, {"some-attr", "value"}], children: [
        %HTMLNode{name: "p", attributes: [
            {"another-attr", "value"}, {"id", "id"}, {"wrapped-attr", "value"}]}
      ]}
    ]
  end

  test "embedded code" do
    slime = """
    = for thing <- stuff do
      - output = process(thing)
      p
        = output
    """
    assert parse(slime) == [
      %EExNode{code: "for thing <- stuff do", output: true, children: [
        %EExNode{code: "output = process(thing)"},
        %HTMLNode{name: "p", children: [
          %EExNode{code: "output", output: true}]}
      ]}
    ]
  end

  test "inline eex" do
    slime = """
    p some-attribute=inline = hey
    span Text
    """
    assert parse(slime) == [
      %HTMLNode{name: "p",
        attributes: [
          {"some-attribute", %EExNode{code: "inline", output: true}}],
        children: [
          %EExNode{code: "hey", output: true}]},
      %HTMLNode{name: "span", children: ["Text"]}
    ]
  end

  test "verbatim text nodes" do
    slime = ~S"""
    | multiline
       text with #{interpolation}
    ' and trailing whitespace
    """
    assert parse(slime) == [
      %VerbatimTextNode{content: [
        %EExNode{code: "\"multiline text with \#{interpolation}\"", output: true}]},
      %VerbatimTextNode{content: ["and trailing whitespace", " "]},
    ]
  end

  test "html comments" do
    slime = "/! html comment"
    assert parse(slime) == [%HTMLCommentNode{content: ["html comment"]}]
  end
end