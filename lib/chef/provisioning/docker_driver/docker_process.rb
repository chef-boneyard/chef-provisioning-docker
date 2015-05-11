class Chef
module Provisioning
class DockerProcess
  def self.run(*args, &block)
    new(*args, &block).run
  end

  attr_reader :transport
  attr_reader :command
  attr_reader :options
  attr_reader :stdout
  attr_reader :stderr
  attr_reader :exit_code

  protected

  def initialize(transport, command, options = {})
    @transport = transport
    @command = command
    @options = options
    run
  end

  def stream_stdout
    @stream_stdout ||= begin
      stream = options.has_key?(:stream_stdout) ? options[:stream_stdout] : options[:stream]
      stream = config[:stdout] || $stdout if stream == true
      stream
    end
  end
  def stream_stderr
    @stream_stderr ||= begin
      stream = options.has_key?(:stream_stderr) ? options[:stream_stderr] : options[:stream]
      stream = config[:stderr] || $stderr if stream == true
      stream
    end
  end
  def stream_stdin
    @stream_stdin ||= begin
      stream = options[:stream_stdin]
      stream = config[:stdin] || $stdin if stream == true
      stream
    end
  end
  def tty?
    !!options[:tty]
  end
  def connection
    transport.connection
  end
  def config
    transport.config
  end
  def config
    transport.container_name
  end

  def run
    exec = Docker::Exec.create(connection,
      'Container' => container_name,
      'AttachStdin' => !!stream_stdin,
      'AttachStdout' => !!stream_stdout,
      'AttachStderr' => !!stream_stderr,
      'Tty' => tty?,
      'Cmd' => command
    )
    @stdout, @stderr, @exit_code = exec.run(stdin: stream_stdin, tty: tty?) do |stream, output=nil|
      if tty?
        stream, output = :stdout, stream
      end
      case stream
      when :stdout
        stream_stdout << output if stream_stdout
      when :stderr
        stream_stderr << output if stream_stderr
      end
    end
    self
  end
end
end
end
