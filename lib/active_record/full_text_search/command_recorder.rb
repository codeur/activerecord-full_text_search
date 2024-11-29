module ActiveRecord
  module FullTextSearch
    register :command_recorder do
      require "active_record/migration/command_recorder"
      ActiveRecord::Migration::CommandRecorder.include CommandRecorder
    end

    # ActiveRecord::Migration::CommandRecorder is a class used by reversible migrations.
    # It captures the forward migration commands and translates them into their inverse
    # by way of some simple metaprogramming.
    #
    # The Migrator class uses CommandRecorder during the reverse migration instead of
    # the connection object. Forward migration calls are translated to their inverse
    # where possible, and then forwarded to the connetion. Irreversible migrations
    # raise an exception.
    #
    # Known schema statement methods are metaprogrammed into an inverse method like so:
    #
    #   create_table => invert_create_table
    #
    # which returns:
    #
    #   [:drop_table, args.first]
    module CommandRecorder
      def create_function(*args, &block)
        record(:create_function, args, &block)
      end

      def drop_function(*args, &block)
        record(:drop_function, args, &block)
      end

      def create_text_search_configuration(*args, &block)
        record(:create_text_search_configuration, args, &block)
      end

      def drop_text_search_configuration(*args, &block)
        record(:drop_text_search_configuration, args, &block)
      end

      def rename_text_search_configuration(*args, &block)
        record(:rename_text_search_configuration, args, &block)
      end

      def add_text_search_configuration_mappingping(*args, &block)
        record(:add_text_search_configuration_mappingping, args, &block)
      end

      def change_text_search_configuration_mapping(*args, &block)
        record(:change_text_search_configuration_mapping, args, &block)
      end

      def replace_text_search_configuration_dictionary(*args, &block)
        record(:replace_text_search_configuration_dictionary, args, &block)
      end

      def drop_text_search_configuration_mapping(*args, &block)
        record(:drop_text_search_configuration_mapping, args, &block)
      end

      def create_text_search_dictionary(*args, &block)
        record(:create_text_search_dictionary, args, &block)
      end

      def drop_text_search_dictionary(*args, &block)
        record(:drop_text_search_dictionary, args, &block)
      end

      def rename_text_search_dictionary(*args, &block)
        record(:rename_text_search_dictionary, args, &block)
      end

      def change_text_search_dictionary_option(*args, &block)
        record(:change_text_search_dictionary_option, args, &block)
      end

      def create_text_search_parser(*args, &block)
        record(:create_text_search_parser, args, &block)
      end

      def drop_text_search_parser(*args, &block)
        record(:drop_text_search_parser, args, &block)
      end

      def rename_text_search_parser(*args, &block)
        record(:rename_text_search_parser, args, &block)
      end

      def create_text_search_template(*args, &block)
        record(:create_text_search_template, args, &block)
      end

      def drop_text_search_template(*args, &block)
        record(:drop_text_search_template, args, &block)
      end

      def rename_text_search_template(*args, &block)
        record(:rename_text_search_template, args, &block)
      end

      private

      def invert_create_function(args)
        [:drop_function, args]
      end

      def invert_drop_function(args)
        [:create_function, args]
      end

      def invert_create_text_search_configuration(args)
        [:drop_text_search_configuration, args]
      end

      def invert_drop_text_search_configuration(args)
        [:create_text_search_configuration, args]
      end

      def invert_rename_text_search_configuration(args)
        [:rename_text_search_configuration, [args.last[:to], to: args.first]]
      end

      def invert_add_text_search_configuration_mappingping(args)
        [:drop_text_search_configuration_mapping, args]
      end

      def invert_change_text_search_configuration_mapping(args)
        [:change_text_search_configuration_mapping, args]
      end

      def invert_replace_text_search_configuration_dictionary(args)
        [:replace_text_search_configuration_dictionary, args.values_at(:to, :from)]
      end

      def invert_drop_text_search_configuration_mapping(args)
        [:add_text_search_configuration_mappingping, args]
      end

      def invert_create_text_search_dictionary(args)
        [:drop_text_search_dictionary, args]
      end

      def invert_drop_text_search_dictionary(args)
        [:create_text_search_dictionary, args]
      end

      def invert_rename_text_search_dictionary(args)
        [:rename_text_search_dictionary, [args.last[:to], to: args.first]]
      end

      def invert_change_text_search_dictionary_option(args)
        [:change_text_search_dictionary_option, args.values_at(:option, :default)]
      end

      def invert_create_text_search_parser(args)
        [:drop_text_search_parser, args]
      end

      def invert_drop_text_search_parser(args)
        [:create_text_search_parser, args]
      end

      def invert_rename_text_search_parser(args)
        [:rename_text_search_parser, [args.last[:to], to: args.first]]
      end

      def invert_create_text_search_template(args)
        [:drop_text_search_template, args]
      end

      def invert_drop_text_search_template(args)
        [:create_text_search_template, args]
      end

      def invert_rename_text_search_template(args)
        [:rename_text_search_template, [args.last[:to], to: args.first]]
      end
    end
  end
end
