module ActiveRecord
  module FullTextSearch
    register :schema_statements do
      require "active_record/connection_adapters/postgresql_adapter"
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include SchemaStatements
    end

    module SchemaStatements
      def create_function(name_with_args, as:, volatility: :volatile, language: "sql", returns: "void", replace: true)
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

      def drop_function(name_with_args, if_exists: false, cascade: false)
        execute "DROP FUNCTION #{"IF EXISTS" if if_exists} #{name_with_args} #{"CASCADE" if cascade}"
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
    end
  end
end
