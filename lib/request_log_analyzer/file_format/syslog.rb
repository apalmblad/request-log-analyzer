module RequestLogAnalyzer::FileFormat
  module Syslog
    def self.get_other_classes
      klasses = []
      RequestLogAnalyzer::FileFormat.constants.each do |const|
        next if const == 'Base'
        next if const == 'Syslog'
        klass = RequestLogAnalyzer::FileFormat.module_eval("#{const}", __FILE__, __LINE__)
        if klass.is_a?( Class )
          klasses << klass
        end
      end
      return klasses
    end
    def self.build_syslog_definition( old_def )
      new_captures =[ { :name => :date, :type => :string },
          { :name => :time, :type => :string },
          { :name => :user, :type => :string },
          { :name => :program_name, :type => :string },
          { :name => :pid, :type => :string }]
      extracted_teaser = old_def.teaser ? old_def.teaser.inspect.gsub( /(^\/)|(\/$)/, '' ) : ''
      extracted_regexp = old_def.regexp ? old_def.regexp.inspect.gsub( /(^\/)|(\/$)/, '' ) : ''
      RequestLogAnalyzer::LineDefinition.new( old_def.name,
          :teaser => old_def.teaser ? /\w\w\w \d\d \d\d:\d\d:\d\d [\w-]+ [\w-]+\[\d+\]: #{extracted_teaser}/ : nil,
          :regexp =>  /(\w\w\w \d\d) (\d\d:\d\d:\d\d) ([\w-]+) ([\w-]+)\[(\d+)\]: #{extracted_regexp}/,
          :captures => new_captures + old_def.captures,
          :header => old_def.header,
          :footer => old_def.footer )
    end
    # ------------------------------------------------------------ get_instances
    def self.get_instances( *args )
      r_val = []
      get_other_classes.each do |k|
        k.name =~ /\:\:([^\:]+)$/
        klass = module_eval( "Syslog::#{$1}" )
        r_val << klass.create( *args )
      end
      return r_val
    end
  end

  Syslog.get_other_classes.each do |klass|
    klass.name =~ /\:\:([^\:]+)$/

    module_eval <<-EOS
      class Syslog::#{$1} < #{klass.name}
        def line_definitions
          @altered_line_defs ||= begin
            old_defs = super
            r_val = {}
            old_defs.keys.each do |x|
              r_val[x] = Syslog.build_syslog_definition( old_defs[x] )
            end
            r_val
          end
        end
        def is_syslog?
          true
        end
      end
    EOS
  end
end
