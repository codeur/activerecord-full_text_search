module ActiveRecord
  module FullTextSearch
    register :schema_dumper do
      require "active_record/connection_adapters/postgresql/schema_dumper"
      ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend SchemaDumper
    end

    module SchemaDumper
      private

      def extensions(stream)
        super
        functions(stream)
        text_search_parsers(stream)
        text_search_templates(stream)
        text_search_dictionaries(stream)
        text_search_configurations(stream)
      end

      def functions(stream)
        return unless (functions = @connection.functions).any?

        stream.puts "  # These are functions that must be created in order to support this database"

        functions.each do |name, definition|
          source = definition.delete(:source)
          arguments = definition.delete(:arguments)
          stream.puts %{  create_function "#{name}(#{arguments})", #{hash_to_string(definition)}, as: <<~SQL}
          stream.puts source.strip.gsub(/^/, "    ").gsub(/\s+$/, "")
          stream.puts "  SQL"
        end

        stream.puts
      end

      def text_search_parsers(stream)
        return unless (parsers = @connection.text_search_parsers).any?

        stream.puts "  # These are full-text search parsers that must be created in order to support this database"

        parsers.each do |name, definition|
          stream.puts %(  create_text_search_parser "#{name}", #{hash_to_string(definition)})
        end

        stream.puts
      end

      def text_search_templates(stream)
        return unless (templates = @connection.text_search_templates).any?

        stream.puts "  # These are full-text search templates that must be created in order to support this database"

        templates.each do |name, definition|
          stream.puts %(  create_text_search_template "#{name}", #{hash_to_string(definition)})
        end
        stream.puts
      end

      def text_search_dictionaries(stream)
        return unless (dictionaries = @connection.text_search_dictionaries).any?

        stream.puts "  # These are full-text search dictionaries that must be created in order to support this database"

        dictionaries.each do |name, definition|
          stream.puts %(  create_text_search_dictionary "#{name}", #{hash_to_string(definition)})
        end

        stream.puts
      end

      def text_search_configurations(stream)
        return unless (configurations = @connection.text_search_configurations).any?

        stream.puts "  # These are full-text search configurations that must be created in order to support this database"

        configurations.each do |name, definition|
          if definition[:parser] == "default"
            stream.puts %(  create_text_search_configuration "#{name}")
          else
            stream.puts %(  create_text_search_configuration "#{name}", parser: "#{definition[:parser]}")
          end
          definition[:maps].each do |dicts, tokens|
            stream.puts %(  add_text_search_configuration_mapping "#{name}", #{array_to_string(tokens)}, #{array_to_string(dicts)})
          end
        end
        stream.puts
      end

      private

      def hash_to_string(hash)
        hash.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      end

      def array_to_string(array)
        return array.inspect if array.detect { |v| !v.is_a?(String) || v =~ /\s+/ }

        "%w[#{array.join(" ")}]"
      end
    end
  end
end
