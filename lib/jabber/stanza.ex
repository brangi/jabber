defmodule Jabber.Stanza do

  use Jabber.Xml

  alias Jabber.Stanza.Iq
  alias Jabber.Stanza.Message
  alias Jabber.Stanza.Presence
    
  def stream(to, xmlns) do
    xmlstreamstart(
      name: "stream:stream",
      attrs: [{"xmlns:stream", "http://etherx.jabber.org/streams"},
              {"xmlns", xmlns}, {"to", to}])
  end

  def new(xmlel(name: "message", attrs: attrs, children: children) = xml) do
    {"id", id}     = List.keyfind(attrs, "id", 0, {"id", nil})
    {"to", to}     = List.keyfind(attrs, "to", 0, {"to", nil})
    {"from", from} = List.keyfind(attrs, "from", 0, {"from", nil})
    {"type", type} = List.keyfind(attrs, "type", 0, {"type", nil})
    
    attrs = List.keydelete(attrs, "id", 0)
    attrs = List.keydelete(attrs, "to", 0)
    attrs = List.keydelete(attrs, "from", 0)
    attrs = List.keydelete(attrs, "type", 0)
    
    body = get_child(xml, "body") |> get_cdata
    
    %Message{id: id, to: to, from: from, type: type, body: body,
             attrs: attrs, children: children}
  end

  def new(xmlel(name: "presence", attrs: attrs, children: children)) do
    %Presence{attrs: attrs, children: children}
  end

  def new(xmlel(name: "iq", attrs: attrs, children: children)) do
    {"id", id}     = List.keyfind(attrs, "id", 0, {"id", nil})
    {"to", to}     = List.keyfind(attrs, "to", 0, {"to", nil})
    {"from", from} = List.keyfind(attrs, "from", 0, {"from", nil})
    {"type", type} = List.keyfind(attrs, "type", 0, {"type", nil})

    attrs = List.keydelete(attrs, "id", 0)
    attrs = List.keydelete(attrs, "to", 0)
    attrs = List.keydelete(attrs, "from", 0)
    attrs = List.keydelete(attrs, "type", 0)
    
    %Iq{id: id, to: to, from: from, type: type,
        attrs: attrs, children: children}
  end
  
  def to_xml(%Message{} = msg) do
    attrs = attrs_to_binary(msg.attrs, msg.id, msg.to, msg.from, msg.type)
    if msg.body != nil do
      body = xmlel(name: "body", children: [xmlcdata(content: msg.body)])
      children = Enum.filter(
        msg.children,
        fn
          xmlel(name: "body") -> false
           _ -> true
        end)
      children = [body|children]
    else
      children = msg.children
    end
    xmlel(name: "message", attrs: attrs, children: children)
  end

  def to_xml(%Presence{} = stanza) do
    xmlel(name: "presence", attrs: stanza.attrs, children: stanza.children)
  end

  def to_xml(%Iq{} = iq) do
    attrs = attrs_to_binary(iq.attrs, iq.id, iq.to, iq.from, iq.type)
    xmlel(name: "iq", attrs: attrs, children: iq.children)
  end

  ## private API

  defp attrs_to_binary(attrs, id, to, from, type) do
    attrs
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    |> Map.put("id", id)
    |> Map.put("to", to)
    |> Map.put("from", from)
    |> Map.put("type", type)
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end
  
end
