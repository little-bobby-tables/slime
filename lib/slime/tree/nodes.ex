defmodule Slime.Tree.Nodes do
  defmodule HTMLNode do
    defstruct name: "",
              attributes: [],
              spaces: %{},
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

  defmodule DoctypeNode do
    defstruct content: ""
  end
end
