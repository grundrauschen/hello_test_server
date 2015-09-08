defmodule Mix.Tasks.Hellotest do
  use Mix.Task

  @shortdoc "Generate hellotestserver escript"
    @doc """
  Defines the command line behaviour
  """
  def run(argv) do
    argv
    |> parse_args
    |> run_application
    #run_application(:help)
  end

  def parse_args(args) do
    parsed_args = OptionParser.parse(args, strict: [ help: :boolean,
                                                     url: :string,
                                                     path: :string],
                                     aliases: [h: :help])
    case parsed_args do
      {[help: true], _, _}                -> :help
      {[], _, _}                          -> :help
      {args, _, _} when length(args) == 2 -> args
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
    IO.puts(System.cwd)
    exit(:shutdown)
  end

  def run_application(args) do
    Enum.map(args, fn keyword_arg -> config_arg keyword_arg end)
    Application.put_env(:hello_test_server, :run_script, true, persistent: true)
    Mix.Task.run "app.start", []
    no_halt()
  end

  defp config_arg({:url, arg}) do
    Application.put_env(:hello_test_server, :listen, to_char_list(arg), persistent: true)
  end

  defp config_arg({:path, arg}) do
    Application.put_env(:hello_test_server, :respond_path, to_string(arg), persistent: true)
  end
  
  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
