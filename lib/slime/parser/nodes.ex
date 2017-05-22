defmodule Slime.Parser.Nodes do
  defmodule HTMLNode do
    defstruct name: "",
              attributes: [],
              spaces: %{},
              closed: false,
              children: []
  end

  defmodule EExNode do
    defstruct content: "",
              output: false,
              spaces: %{},
              children: []
  end

  defmodule VerbatimTextNode do
    # A list of EExNode items and strings that are later concatenated.
    defstruct content: []
  end

  defmodule HTMLCommentNode do
    defstruct content: []
  end

  defmodule EmbeddedEngineNode do
    defstruct name: "",
              content: []
  end

  defmodule InlineHTMLNode do
    defstruct content: [],
              children: []
  end

  defmodule DoctypeNode do
    defstruct name: ""
  end
end
