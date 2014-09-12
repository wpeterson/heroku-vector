
module HerokuVector
  class ProcessManager
    include HerokuVector::Helper

    attr_accessor :options

    def initialize(options = {})
      @options = options
    end

    def start
      daemonize           if options[:daemonize]
      redirect_to_logfile if options[:logfile]
      write_pid

      worker = Worker.new(options)
      worker.run
    end

    def daemonize
      return unless options[:daemonize]

      raise ArgumentError, "Daemonized mode requires a logfile" unless options[:logfile]
      files_to_reopen = []
      ObjectSpace.each_object(File) do |file|
        files_to_reopen << file unless file.closed?
      end

      ::Process.daemon(true, true)

      files_to_reopen.each do |file|
        begin
          file.reopen file.path, "a+"
          file.sync = true
        rescue ::Exception
        end
      end
    end

    def redirect_to_logfile
      [$stdout, $stderr].each do |io|
        File.open(options[:logfile], 'ab') do |f|
          io.reopen(f)
        end
        io.sync = true
      end
    end

    def write_pid
      return unless path = options[:pidfile]

      pidfile = File.expand_path(path)
      logger.info "Writing pidfile #{pidfile}"
      File.open(pidfile, 'w') do |f|
        f.puts ::Process.pid
      end
    end

  end
end
