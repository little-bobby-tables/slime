defmodule Slime.Parser.TreeTransformTest do
  use ExUnit.Case, async: true

  import Slime.Parser, only: [parse: 1]
  alias Slime.Parser.Nodes.HTMLNode
  alias Slime.Parser.Nodes.EExNode
  alias Slime.Parser.Nodes.VerbatimTextNode
  alias Slime.Parser.Nodes.HTMLCommentNode
  alias Slime.Parser.Nodes.InlineHTMLNode
  alias Slime.Parser.Nodes.DoctypeNode

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

  test "closed nodes" do
    slime = """
    img src="url"/
    """
    assert parse(slime) == [
      %HTMLNode{name: "img", attributes: [{"src", "url"}], closed: true}
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
      %EExNode{content: "for thing <- stuff do", output: true, children: [
        %EExNode{content: "output = process(thing)"},
        %HTMLNode{name: "p", children: [
          %EExNode{content: "output", output: true}]}
      ]}
    ]
  end

  test "embedded code (else is a child of if)" do
    slime = """
    = if condition do
      | Something


    - else
      | Something else
    """
    assert parse(slime) == [
      %EExNode{content: "if condition do", output: true, children: [
        %VerbatimTextNode{content: ["Something"]},
        %EExNode{content: "else", children: [
          %VerbatimTextNode{content: ["Something else"]}]},
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
        attributes: [{"some-attribute", {:eex, "inline"}}],
        children: [%EExNode{content: "hey", output: true}]},
      %HTMLNode{name: "span", children: ["Text"]}
    ]
  end

  test "inline html" do
    slime = ~S"""
    <html>
      head
        <meta content="#{interpolation}"/>
      <body>
        table
          = for a <- articles do
            <tr>#{a.name}</tr>
      </body>
    </html>
    """
    assert parse(slime) == [
      %InlineHTMLNode{content: ["<html>"], children: [
        %HTMLNode{name: "head", children: [
          %InlineHTMLNode{content: [
            %EExNode{content:
              "\"<meta content=\\\"\#{interpolation}\\\"/>\"", output: true}]}
        ]},
        %InlineHTMLNode{content: ["<body>"], children: [
          %HTMLNode{name: "table", children: [
            %EExNode{content: "for a <- articles do", output: true, children: [
              %InlineHTMLNode{content: [
                %EExNode{content: "\"<tr>\#{a.name}</tr>\"", output: true}]}]}
          ]}
        ]},
        %InlineHTMLNode{content: ["</body>"]}
      ]},
      %InlineHTMLNode{content: ["</html>"]}
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
        %EExNode{content: "\"multiline text with \#{interpolation}\"",
                 output: true}]},
      %VerbatimTextNode{content: ["and trailing whitespace", " "]},
    ]
  end

  test "html comments" do
    slime = "/! html comment"
    assert parse(slime) == [%HTMLCommentNode{content: ["html comment"]}]
  end

  test "doctype" do
    slime = """
    doctype html
    div
    """
    assert parse(slime) == [
      %DoctypeNode{content: "html"},
      %HTMLNode{name: "div"}
    ]
  end
end
