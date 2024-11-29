module ActiveRecord
  module FullTextSearch
    register :postgresql_adapter do
      require "active_record/connection_adapters/postgresql_adapter"
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include ::ActiveRecord::FullTextSearch::PostgreSQLAdapter
    end

    module PostgreSQLAdapter
      VOLATILITIES = {
        "i" => :immutable,
        "s" => :stable,
        "v" => :volatile
      }.freeze

      def functions
        # List of functions in the current schema with their argument types, return type, language,  immutability, and body.
        # List only functions that don't depend on extensions.
        res = exec_query(<<-SQL.strip_heredoc, "SCHEMA")
          SELECT proname, pg_catalog.pg_get_function_arguments(p.oid) AS argtypes, pg_catalog.pg_get_function_result(p.oid) AS rettype, lanname, provolatile, prosrc
          FROM pg_catalog.pg_proc p
          JOIN pg_catalog.pg_namespace n ON n.oid = pronamespace
          JOIN pg_catalog.pg_language l ON l.oid = prolang
          LEFT JOIN pg_catalog.pg_depend d ON d.objid = p.oid AND d.deptype = 'e'
          LEFT JOIN pg_catalog.pg_extension e ON e.oid = d.refobjid
          WHERE n.nspname = ANY (current_schemas(false))
            AND e.extname IS NULL;
        SQL

        res.rows.each_with_object({}) do |(name, args, ret, lang, vol, src), memo|
          memo[name] = {arguments: args, returns: ret, language: lang, volatility: VOLATILITIES[vol], source: src}
        end
      end

      def text_search_parsers
        res = exec_query(<<-SQL.strip_heredoc, "SCHEMA")
          SELECT prsname, prsstart::VARCHAR, prstoken::VARCHAR, prsend::VARCHAR, prsheadline::VARCHAR, prslextype::VARCHAR
          FROM pg_catalog.pg_ts_parser
          LEFT JOIN pg_catalog.pg_depend AS d ON d.objid = pg_ts_parser.oid AND d.deptype = 'e'
          LEFT JOIN pg_catalog.pg_extension AS e ON e.oid = d.refobjid
          WHERE prsnamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = ANY (current_schemas(false)))
            AND e.extname IS NULL;
        SQL

        res.rows.each_with_object({}) do |(name, start, token, finish, headline, lextype), memo|
          memo[name] = {start: start, token: token, finish: finish, headline: headline, lextype: lextype}
        end
      end

      def text_search_templates
        res = exec_query(<<-SQL.strip_heredoc, "SCHEMA")
          SELECT tmplname, tmplinit::VARCHAR, tmpllexize::VARCHAR
          FROM pg_catalog.pg_ts_template
          LEFT JOIN pg_catalog.pg_depend AS d ON d.objid = pg_ts_template.oid AND d.deptype = 'e'
          LEFT JOIN pg_catalog.pg_extension AS e ON e.oid = d.refobjid
          WHERE tmplnamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = ANY (current_schemas(false)))
            AND tmplnamespace NOT IN (SELECT extnamespace FROM pg_extension)
            AND e.extname IS NULL;
        SQL

        res.rows.each_with_object({}) { |(name, init, lexize), memo| memo[name] = {init: init, lexize: lexize} }
      end

      def text_search_dictionaries
        res = exec_query(<<-SQL.strip_heredoc, "SCHEMA")
          SELECT dictname, tns.nspname || '.' || tmplname, dictinitoption
          FROM pg_catalog.pg_ts_dict
          LEFT JOIN pg_catalog.pg_ts_template AS t ON dicttemplate = t.oid
          LEFT JOIN pg_catalog.pg_namespace AS tns ON t.tmplnamespace = tns.oid
          LEFT JOIN pg_catalog.pg_depend AS d ON d.objid = dicttemplate AND d.deptype = 'e'
          LEFT JOIN pg_catalog.pg_extension AS e ON e.oid = d.refobjid
          WHERE dictnamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = ANY (current_schemas(false)))
            AND e.extname IS NULL;
        SQL

        res.rows.each_with_object({}) { |(name, template, init), memo| memo[name] = options_to_hash(init).reverse_merge(template: template) }.sort_by { |k, _| k.to_s }.sort_by { |_, v| v[:dictionary].nil? ? 0 : 1 }
      end

      def text_search_configurations
        res = exec_query(<<-SQL.strip_heredoc, "SCHEMA")
          SELECT cfg.oid, cfgname, cfgparser, prsname
          FROM pg_catalog.pg_ts_config AS cfg
          LEFT JOIN pg_catalog.pg_ts_parser ON cfgparser = pg_ts_parser.oid
          LEFT JOIN pg_catalog.pg_depend AS d ON d.objid = cfgparser AND d.deptype = 'e'
          LEFT JOIN pg_catalog.pg_extension AS e ON e.oid = d.refobjid
          WHERE cfgnamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = ANY (current_schemas(false)))
            AND e.extname IS NULL;
        SQL

        res.rows.each_with_object({}) do |(oid, name, parser_oid, parser_name), memo|
          maps = exec_query(<<-SQL.strip_heredoc, "SCHEMA")
            SELECT t.alias AS "token", dictname AS "dict"
            FROM pg_catalog.pg_ts_config_map
            JOIN (SELECT * FROM ts_token_type(#{parser_oid})) AS t ON maptokentype = t.tokid
            JOIN pg_catalog.pg_ts_dict ON mapdict = pg_ts_dict.oid
            WHERE mapcfg = #{oid}
            ORDER BY mapseqno;
          SQL
          maps = maps.rows.each_with_object({}) { |(token, dict), memo|
            memo[token] ||= []
            memo[token] << dict
          }
          maps = maps.each_with_object({}) { |(k, v), memo|
            memo[v] ||= []
            memo[v] << k
          }
          memo[name] = {parser: parser_name, maps: maps}
        end
      end

      private

      def options_to_hash(text)
        text.split(/\s*,\s*/).map { |s| s.strip.split(/\s+=\s+/) }.to_h.transform_values { |v| v[1..-2] }.transform_keys(&:to_sym)
      end
    end
  end
end
