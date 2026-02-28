require 'tty-command'

class TerminalRunner
  def self.run(cmd)
    @cmd ||= TTY::Command.new(printer: :null)
    result = @cmd.run!(cmd)

    {
      command: cmd,
      output: result.out + result.err,
      exit_status: result.exit_status
    }
  rescue TTY::Command::ExitError => e
    {
      command: cmd,
      output: e.message,
      exit_status: 1
    }
  end
end
