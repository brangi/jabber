defmodule Jabber.Component do

  @callback stream_started(state :: term) :: {:ok, term}
  @callback stream_authenticated(state :: term) :: {:ok, term}
  @callback stanza_received(state :: term, stanza :: term) :: {:ok, term}
  
  defmacro __using__(_opts) do
    quote do

      @behaviour :gen_fsm
      
      use Jabber.Xml

      alias Jabber.Stanza
      
      require Logger

      @stream_ns     "jabber:component:accept"
      @initial_state %{conn: nil, conn_pid: nil,
                       jid: nil, stream_id: nil,
                       password: nil, opts: []}

      def start_link(args) do
        :gen_fsm.start_link(__MODULE__, args, [])
      end

      ## component behaviour callbacks
      
      def stream_started(state) do
        # override this
        {:ok, state}
      end

      def stream_authenticated(state) do
        # override this
        {:ok, state}
      end
      
      def stanza_received(state, _stanza) do
        # override this
        {:ok, state}
      end
      
      ## event callbacks

      def connected(:timeout, state) do
        {:ok, state} = wait_for_stream(state)
        {:next_state, :stream_started, state, 0}
      end
      
      def stream_started(:timeout, state) do
        case stream_started(state) do
          {:ok, state} ->
            {:next_state, :authenticating, state, 0}
          {:ok, state, next_state} ->
            {:next_state, next_state, state, 0}
          {:stop, reason, state} ->
            {:stop, reason, state}
        end
      end
      
      def authenticating(:timeout, state) do
        case do_handshake(state) do
          {:ok, state} ->
            {:ok, state} = stream_authenticated(state)
            {:next_state, :authenticated, state}
          {:error, reason} ->
            {:stop, reason, state}
        end
      end
      
      ## :gen_fsm API

      def init(args) do
        jid      = Keyword.fetch!(args, :jid)
        password = Keyword.fetch!(args, :password)
        conn     = Keyword.fetch!(args, :conn)
        opts     = Keyword.fetch!(args, :opts)

        # trap exits
        Process.flag(:trap_exit, true)
        
        # start connection and link to it
        {:ok, conn_pid} = conn.start([{:pid, self} | args])
        true = Process.link(conn_pid)
        
        state = %{@initial_state | jid: jid, conn: conn, conn_pid: conn_pid,
                  password: password, opts: opts}
        
        state |> start_stream(jid)
        
        {:ok, :connected, state, 0}
      end
      
      def handle_info(xmlel() = xml, statename, state) do
        stanza = Stanza.new(xml)
        state = stanza_received(state, stanza)
        {:next_state, statename, state}
      end

      def handle_event({:send, stanza}, statename, %{conn: conn, conn_pid: conn_pid} = state) do
        :ok = conn.send(conn_pid, Stanza.to_xml(stanza))
        {:next_state, statename, state}
      end
      
      def terminate(_reason, _statename, %{conn: conn, conn_pid: conn_pid} = state) do
        stream_xml = Stanza.stream_end
        :ok = conn.send(conn_pid, stream_xml)
      end

      ## private API
      
      defp start_stream(%{conn: conn, conn_pid: conn_pid} = state, jid) do
        stream_xml = Stanza.stream_start(jid, @stream_ns)
        :ok = conn.send(conn_pid, stream_xml)
      end
      
      defp do_handshake(%{conn: conn, conn_pid: conn_pid, password: password} = state) do
        content = :crypto.hash(:sha, "#{state.stream_id}#{password}")
        |> Base.encode16
        |> String.downcase
        
        cdata = xmlcdata(content: content)
        handshake_xml = xmlel(name: "handshake", children: [cdata])

        :ok = conn.send(conn_pid, handshake_xml)
        case recv() do
          {:ok, xmlel(name: "handshake")} ->
            {:ok, state}
          {:error, error} ->
            {:error, error}
        end
      end

      defp wait_for_stream(state) do
        receive do
          xmlstreamstart(attrs: attrs) ->
            {"id", stream_id} = List.keyfind(attrs, "id", 0)
            {:ok, %{state | stream_id: stream_id}}
          _ ->
            wait_for_stream(state)
        end
      end

      defp recv() do
        receive do
          xmlel() = element ->
            {:ok, element}
          xmlel(name: "stream:error") = element ->
            {:error, element}
          _ ->
            recv()
        end
      end
      
      defp recv(name) when is_binary(name) do
        receive do
          xmlel(name: ^name) = element ->
            {:ok, element}
          xmlel(name: "stream:error") = element ->
            {:error, element}
          _ ->
            recv(name)
        end
      end
      
      defoverridable [stream_started: 1, stream_authenticated: 1, stanza_received: 2]
    end
  end
end
