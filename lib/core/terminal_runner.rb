class TerminalRunner
  def self.run(cmd)
    output = `#{cmd} 2>&1`
    {
      command: cmd,
      output: output,
      exit_status: $?.exitstatus
    }
  end
end
