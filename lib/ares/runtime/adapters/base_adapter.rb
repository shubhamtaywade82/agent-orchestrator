# frozen_string_literal: true

require 'open3'
require 'timeout'
require 'ostruct'

module Ares
  module Runtime
    # Abstract base class implementing the Template Method pattern for CLI adapters.
    # Defines the skeleton for execution, timeouts, and retries.
    class BaseAdapter
      DEFAULT_TIMEOUT = 30

      def call(prompt, model = nil, **options)
        cmd = build_command(prompt, model, **options)
        output, status = if options[:interactive]
          run_command_interactive(cmd, prompt)
        else
          execute_with_retry(cmd, prompt, options)
        end

        handle_errors(status, output) unless options[:interactive]
        output
      end

      protected

      def execute_with_retry(cmd, prompt, options)
        output, status = run_with_timeout(cmd, prompt, options)
        return [output, status] unless should_retry?(status, output)

        run_with_timeout(build_retry_command(cmd, prompt, **options), prompt, options)
      end

      def run_with_timeout(cmd, prompt, options = {})
        limit = options[:timeout_seconds] || timeout_seconds
        if Process.respond_to?(:fork) && !Gem.win_platform?
          run_command_in_fork(cmd, prompt, limit)
        else
          Timeout.timeout(limit) { run_command(cmd, prompt) }
        end
      rescue Timeout::Error => e
        limit = options[:timeout_seconds] || timeout_seconds
        raise "#{adapter_name} timed out after #{limit}s: #{e.message}"
      end

      # Run with PTY so the agent's stdin/stdout are connected to the user's terminal.
      def run_command_interactive(cmd, prompt)
        require 'pty'
        output = +''
        status = nil
        PTY.spawn(*cmd) do |r, w, pid|
          w.write(prompt)
          w.flush
          reader = Thread.new do
            begin
              loop { data = r.readpartial(4096); output << data; $stdout.write(data); $stdout.flush }
            rescue Errno::EIO, EOFError
              # pty closed
            end
          end
          begin
            loop { w.write($stdin.readpartial(4096)); w.flush }
          rescue Errno::EIO, EOFError
            w.close
          end
          reader.join(2)
          _, status = Process.wait2(pid)
        end
        [output, status]
      rescue LoadError
        # PTY not available (e.g. Windows), fall back to non-interactive
        run_command(cmd, prompt)
      end

      # Run in fork so Timeout in parent never closes pipes used by Open3 (avoids
      # "stream closed in another thread" when Timeout fires during capture2e/popen2e).
      def run_command_in_fork(cmd, prompt, limit = timeout_seconds)
        reader, writer = IO.pipe
        pid = fork do
          reader.close
          output, status = run_command(cmd, prompt)
          writer.write(Marshal.dump([output, status.success?, status.exitstatus]))
        end
        writer.close
        begin
          result = Timeout.timeout(limit) { Marshal.load(reader.read) }
        rescue Timeout::Error
          Process.kill(:TERM, pid)
          Process.wait(pid)
          raise
        end
        reader.close
        Process.wait(pid)
        output, success, exitstatus = result
        status = OpenStruct.new(success?: success, exitstatus: exitstatus)
        [output, status]
      end

      def run_command(cmd, prompt)
        stdin_data = pipes_prompt_to_stdin? ? prompt : nil
        capture2e_single_thread(cmd, stdin_data)
      end

      # Single-threaded capture to avoid "stream closed in another thread" when used
      # after TTY::Prompt / TTY::Spinner or under Timeout (Open3.capture2e uses a reader thread).
      def capture2e_single_thread(cmd, stdin_data)
        Open3.popen2e(*cmd) do |stdin, outerr, wait_thr|
          stdin.write(stdin_data) if stdin_data
          stdin.close
          [outerr.read, wait_thr.value]
        end
      end

      def handle_errors(status, output)
        raise "#{adapter_name} command failed: #{output}" unless status.success?
      end

      def build_command(prompt, model, **options)
        raise NotImplementedError, "#{self.class} must implement #build_command"
      end

      def pipes_prompt_to_stdin?
        true
      end

      def should_retry?(_status, _output)
        false
      end

      def build_retry_command(cmd, _prompt, **_options)
        cmd
      end

      def timeout_seconds
        DEFAULT_TIMEOUT
      end

      def adapter_name
        self.class.name.split('::').last.sub('Adapter', '')
      end
    end
  end
end
