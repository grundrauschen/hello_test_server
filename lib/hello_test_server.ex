defmodule HelloTestServer do
  use Application
  use Mix.Config

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @rrtable :test_server_round_roubin_table
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(HelloTestServer.Worker, [arg1, arg2, arg3]),
    ]
    Hello.start_listener(url(), [], :hello_proto_jsonrpc, [], HelloTestServer.Router)
    Hello.bind(url(), __MODULE__)
    :ets.new(@rrtable, [:named_table, :public])
    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HelloTestServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def url(), do: Application.get_env(:hello_test_server, :listen)
  defp path(), do: Application.get_env(:hello_test_server, :respond_path)
  def name(), do: "ping/server"
  def router_key(), do: ""
  def validation(), do: __MODULE__
  def request(_, m, p), do: {:ok, m, p}

  def init(_identifier, _), do: {:ok, 0}

  def to_integer(intlike) do
    case intlike do
    intlike when is_integer(intlike) -> intlike
    intlike when is_binary(intlike) -> String.to_integer(intlike)
    end
  end

  def random(upper) do
    :crypto.rand_uniform(1, upper)
  end

  def handle_request(_context, "Server.ping", args, state) do
    case args do
      %{"rsleep" => rsleep} -> rsleep |> to_integer() |> random() |> :timer.sleep
      %{"sleep" => sleep}   -> sleep  |> to_integer() |> :timer.sleep
      _ -> nil
    end
    {:stop, :normal, {:ok, "pong"}, state}
  end

  def handle_request(_context, method, args, state) do
    dirname = Application.app_dir(:hello_test_server, path()) |> Path.join(method)
    case File.ls(dirname) do
      {:ok, files} -> 
        counter = case :ets.lookup(@rrtable, method) do
          [{^method, n}] -> n
          _ -> :ets.insert(@rrtable, {method, 0})
          0
        end
        reply = filter_json(dirname, files) |> choose_reply(counter) |> File.read!
        :ets.update_counter(@rrtable, method, {2, 1})
        {:stop, :normal, {:ok, :jsx.decode(reply)}, state}
      _ -> 
        scriptName = dirname <> ".ex"
        case File.exists?(scriptName) do
          true -> 
            {reply, _} = File.read!(scriptName) |> Code.eval_string([params: args])
            {:stop, :normal, {:ok, reply}, state}
          false -> {:stop, :normal, {:ok, "not_found"}, state}
        end
    end
  end

  def handle_info(_context, _message, state) do
    {:noreply, state}
  end

  def terminate(_context, _reason, _state) do
    :ok
  end

  def client(), do: client("Server.ping")
  def client(method), do: client(method, [])
  def client(method, params) do
    Hello.Client.start({:local, __MODULE__}, url(), [], [], [])
    Hello.Client.call(__MODULE__, {method, params, []})
  end


  defp filter_json(dirname, files) do
    for file <- files, Path.extname(file) == ".json" do
      Path.join(dirname, file)
    end
  end

  defp choose_reply(files, counter) do
    Enum.at(files, rem(counter, length(files)))
  end

  @doc """
  Defines the command line behaviour
  """
  def main(argv) do
    argv
    |> parse_args
    |> run_application
  end

  def parse_args(args) do
    parsed_args = OptionParser.parse(args, switches: [ help: :boolean,
                                                       url: :string,
                                                       path: :string],
                                     aliases: [h: :help])
    case parsed_args do
      {[help: true], _, _} -> :help
      {[], _, _}           -> :help
      {args, _, _}         -> args
                         _ -> :help
    end
  end

  def run_application(:help) do
    IO.puts """
    usage: hello_test_server [-h | --help] [--url URL] [--path PATH]

    where URL in form of <protocol>://<host>[:<port>]
    Supported protocols are: zmq-tcp, zmq-tcp6, zmq-ipc, http
    It is possible to specify port as 0 or * to using only mdns registration

    PATH has to contain the possible requests in the format:
    <PATH>/request/response[1..n].json
    """
  end

  def run_application(args) do
    Enum.map(args, fn keyword_arg -> config_arg(keyword_arg) end)
    Application.start(HelloTestServer)
  end

  defp config_arg(url: arg) do
    Application.put_env(:hello_test_server, :listen, to_char_list(arg), persistent: true)
  end

  defp config_arg(path: arg) do
    Application.put_env(:hello_test_server, :respond_path, to_string(arg), persistent: true)
  end

end

defmodule HelloTestServer.Router do
  require Record
  Record.defrecordp(:context, Record.extract(:context, from_lib: "hello/include/hello.hrl"))

  def route(context(session_id: id), _request, _uri) do
    {:ok, HelloTestServer .name(), id}
  end
end
