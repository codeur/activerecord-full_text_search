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

      # See https://github.com/postgres/postgres/blob/master/src/include/commands/trigger.h
      # and https://stackoverflow.com/questions/23634550/meanings-of-bits-in-trigger-type-field-tgtype-of-postgres-pg-trigger
      def triggers
        # List of triggers in the current schema with name, table name, function, timing, op, for each, condition, deferrable, initially_deferred.
        res = exec_query(<<-SQL.strip_heredoc, "SCHEMA")
          SELECT tgname, c.relname, proname,
            COALESCE(
              CASE WHEN (tgtype::int::bit(7) & b'0000010')::int = 0 THEN NULL ELSE 'before' END,
              CASE WHEN (tgtype::int::bit(7) & b'0000010')::int = 0 THEN 'after' ELSE NULL END,
              CASE WHEN (tgtype::int::bit(7) & b'1000000')::int = 0 THEN NULL ELSE 'instead_of' END,
              ''
            ) as tg_timing,
            (CASE WHEN (tgtype::int::bit(7) & b'0000100')::int = 0 THEN '' ELSE ' insert' END)
            || (CASE WHEN (tgtype::int::bit(7) & b'0001000')::int = 0 THEN '' ELSE ' delete' END)
            || (CASE WHEN (tgtype::int::bit(7) & b'0010000')::int = 0 THEN '' ELSE ' update' END)
            -- || (CASE WHEN (tgtype::int::bit(7) & b'0100000')::int = 0 THEN '' ELSE ' truncate' END)
            AS tg_ops,
            CASE WHEN (tgtype::int::bit(7) & b'0000001')::int = 0 THEN 'statement' ELSE 'row' END as tg_foreach,
            pg_get_expr(tgqual, tgrelid) AS tg_condition,
            tgdeferrable,
            tginitdeferred
          FROM pg_catalog.pg_trigger t
          JOIN pg_catalog.pg_class c ON c.oid = tgrelid
          JOIN pg_catalog.pg_proc f ON f.oid = t.tgfoid
          JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          LEFT JOIN pg_catalog.pg_depend d ON d.objid = t.oid AND d.deptype = 'e'
          LEFT JOIN pg_catalog.pg_extension e ON e.oid = d.refobjid
          WHERE n.nspname = ANY (current_schemas(false))
            AND tgisinternal = FALSE
            AND e.extname IS NULL;
        SQL

        res.rows.each_with_object({}) do |(name, table, function, timing, ops, for_each, condition, deferrable, initially_deferred), memo|
          attributes = {table: table, function: function, for_each: for_each.to_sym}
          attributes[:when] = condition if condition.present?
          attributes[timing.to_sym] = ops.strip.split(/\s+/).map(&:to_sym)
          attributes[:deferrable] = initially_deferred ? :initially_deferred : true if deferrable
          memo[name] = attributes
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
