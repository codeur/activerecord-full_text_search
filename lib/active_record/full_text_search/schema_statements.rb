module ActiveRecord
  module FullTextSearch
    register :schema_statements do
      require "active_record/connection_adapters/postgresql_adapter"
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include SchemaStatements
    end

    module SchemaStatements
      def create_function(name_with_args, as:, volatility: :volatile, language: nil, returns: :void, replace: true)
        name_with_args = "#{name_with_args}()" unless name_with_args.to_s.include?("(")
        language = "plpgsql" if returns == :trigger
        language ||= "sql"
        execute(<<-SQL)
          CREATE #{"OR REPLACE" if replace} FUNCTION #{name_with_args}
          RETURNS #{returns}
          AS $$
          #{as}
          $$
          LANGUAGE #{language}
          #{volatility.to_s.upcase}
        SQL
      end

      def drop_function(name_with_args, options = {})
        if_exists = options[:if_exists]
        cascade = options[:cascade]
        execute "DROP FUNCTION #{"IF EXISTS" if if_exists} #{name_with_args} #{"CASCADE" if cascade}"
      end

      def create_trigger(table, function, options = {})
        raise ArgumentError, "function name is invalid" unless /\A\w+\z/.match?(function.to_s)
        raise ArgumentError, "Must specify one and only one of the options :before, :after, or :instead_of" unless %i[before after instead_of].select { |t| options.key?(t) }.count == 1
        raise ArgumentError, "for_each must be :row or :statement" if options[:for_each] && !%i[row statement].include?(options[:for_each])

        timing = %i[before after instead_of].find { |t| options.key?(t) }
        operations = options[timing] || raise(ArgumentError, "Must specify operations for #{timing} trigger")
        operations.detect { |op| %i[insert update delete].exclude?(op) } && raise(ArgumentError, "Invalid operation for trigger: #{operations.inspect}")
        for_each = "FOR EACH #{options[:for_each].to_s.upcase}" if options[:for_each]
        if options[:deferrable] == :initially_deferred
          deferrability = "DEFERRABLE INITIALLY DEFERRED"
        elsif options[:deferrable] == :initially_immediate
          deferrability = "DEFERRABLE INITIALLY IMMEDIATE"
        elsif options[:deferrable] == true
          deferrability = "DEFERRABLE"
        elsif options[:deferrable] == false
          deferrability = "NOT DEFERRABLE"
        elsif options[:deferrable]
          raise ArgumentError, "Invalid value for :deferrable"
        end
        condition = options[:when] ? "WHEN (#{options[:when]})" : ""
        operations = [operations].flatten.map do |event|
          if %i[insert update delete].include?(event)
            event.to_s.upcase
          # elsif event.is_a?(Hash)
          #   raise ArgumentError, "Key must be :update" unless event.keys.size == 1 && event.keys.first == :update
          #   "UPDATE OF #{[event[:update]].flatten.map { |c| quote_column_name(c) }.join(", ")}"
          else
            raise ArgumentError, "Unsupported event: #{event.inspect}"
          end
        end
        name = options[:name] || default_trigger_name(table, function, timing, operations)

        execute "CREATE TRIGGER #{name} #{timing.to_s.upcase} #{operations.join(" OR ")} ON #{table} #{for_each} #{deferrability} #{condition} EXECUTE FUNCTION #{function}()"
      end

      def drop_trigger(table, function, options = {})
        if_exists = options[:if_exists]
        cascade = options[:cascade]
        if options.keys.intersect?(%i[before after instead_of])
          raise ArgumentError, "Must specify only one of the options :before, :after, or :instead_of" unless %i[before after instead_of].select { |t| options.key?(t) }.count == 1
          timing = %i[before after instead_of].find { |t| options.key?(t) }
          operations = options[timing] || raise(ArgumentError, "Must specify operations for #{timing} trigger")
        end
        name = options[:name] || default_trigger_name(table, function, timing, operations)
        execute "DROP TRIGGER #{"IF EXISTS" if if_exists} #{name} ON #{table} #{"CASCADE" if cascade}"
      end

      def create_text_search_template(name, lexize:, init: nil)
        options = {init: init, lexize: lexize}.compact
        execute("CREATE TEXT SEARCH TEMPLATE public.#{name} (#{options.map { |k, v| "#{k.upcase} = #{v}" }.join(", ")})")
      end

      def rename_text_search_template(name, to)
        execute "ALTER TEXT SEARCH TEMPLATE public.#{name} RENAME TO #{to}"
      end

      def drop_text_search_template(name, if_exists: false, cascade: :restrict)
        execute "DROP TEXT SEARCH TEMPLATE #{"IF EXISTS" if if_exists} public.#{name} #{"CASCADE" if cascade == :cascade}"
      end

      def create_text_search_dictionary(name, options = {})
        raise ArgumentError, "Must specify :template" unless (template = options.delete(:template))
        execute("CREATE TEXT SEARCH DICTIONARY public.#{name} (TEMPLATE = #{template}#{options.map { |k, v| ", #{k} = '#{v}'" }.join})")
      end

      def rename_text_search_dictionary(name, to)
        execute("ALTER TEXT SEARCH DICTIONARY public.#{name} RENAME TO #{to}")
      end

      def change_text_search_dictionary_option(name, option, value = :default)
        execute("ALTER TEXT SEARCH DICTIONARY public.#{name} SET #{option} #{value if value != :default}")
      end

      def drop_text_search_dictionary(name, if_exists: false, cascade: :restrict)
        execute "DROP TEXT SEARCH DICTIONARY #{"IF EXISTS" if if_exists} public.#{name} #{"CASCADE" if cascade == :cascade}"
      end

      def create_text_search_parser(name, start:, gettoken:, end:, lextypes:, headline: nil)
        options = {start: start, gettoken: gettoken, end: binding.local_variable_get(:end), lextypes: lextypes, headline: headline}.compact
        execute("CREATE TEXT SEARCH PARSER public.#{name} (#{options.map { |k, v| "#{k.upcase} = #{v}" }.join(", ")})")
      end

      def rename_text_search_parser(name, to)
        execute "ALTER TEXT SEARCH PARSER public.#{name} RENAME TO #{to}"
      end

      def drop_text_search_parser(name, if_exists: false, cascade: :restrict)
        execute "DROP TEXT SEARCH PARSER #{"IF EXISTS" if if_exists} public.#{name} #{"CASCADE" if cascade == :cascade}"
      end

      def create_text_search_configuration(name, parser: nil, copy: nil)
        if copy
          execute("CREATE TEXT SEARCH CONFIGURATION public.#{name} (COPY = #{copy})")
        else
          execute("CREATE TEXT SEARCH CONFIGURATION public.#{name} (PARSER = '#{parser || "default"}')")
        end
      end

      def rename_text_search_configuration(name, to)
        execute "ALTER TEXT SEARCH CONFIGURATION public.#{name} RENAME TO #{to}"
      end

      def add_text_search_configuration_mapping(name, token_types, dictionaries)
        execute "ALTER TEXT SEARCH CONFIGURATION public.#{name} ADD MAPPING FOR #{token_types.join(", ")} WITH #{dictionaries.join(", ")}"
      end

      def change_text_search_configuration_mapping(name, token_types, dictionaries)
        execute "ALTER TEXT SEARCH CONFIGURATION public.#{name} ALTER MAPPING FOR #{token_types.join(", ")} WITH #{dictionaries.join(", ")}"
      end

      def replace_text_search_configuration_dictionary(name, from:, to:)
        execute "ALTER TEXT SEARCH CONFIGURATION public.#{name} ALTER MAPPING REPLACE #{from} WITH #{to}"
      end

      def drop_text_search_configuration_mapping(name, token_types, if_exists: false)
        execute "ALTER TEXT SEARCH CONFIGURATION public.#{name} DROP MAPPING #{"IF EXISTS" if if_exists} FOR #{token_types.join(", ")}"
      end

      def drop_text_search_configuration(name, if_exists: false, cascade: :restrict)
        execute "DROP TEXT SEARCH CONFIGURATION #{"IF EXISTS" if if_exists} public.#{name} #{"CASCADE" if cascade == :cascade}"
      end

      def max_trigger_name_size
        62
      end

      private

      # Copied from ActiveRecord::ConnectionAdapters::Abstract::SchemaStatements#foreign_key_name
      def default_trigger_name(table, function, timing, operations)
        identifier = "#{table}_#{function}_#{timing}_#{operations.sort.join('_')}_tg".underscore
        hashed_identifier = OpenSSL::Digest::SHA256.hexdigest(identifier).first(10)
        "tg_rails_#{hashed_identifier}"
      end
    end
  end
end
