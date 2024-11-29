# ActiveRecord::FullTextSearch

This gem adds support for TEXT SEARCH commands in a Rails (>= 7.2) app using PostgreSQL.

It is largely built using the gem [activerecord-pg_enum](https://github.com/alassek/activerecord-pg_enum). Thanks!

## Usage

The gem permits to use these commands:

- `create_function`
- `drop_function`
- `create_text_search_template`
- `rename_text_search_template`
- `drop_text_search_template`
- `create_text_search_parser`
- `rename_text_search_parser`
- `drop_text_search_parser`
- `create_text_search_dictionary`
- `rename_text_search_dictionary`
- `drop_text_search_dictionary`
- `create_text_search_configuration`
- `rename_text_search_configuration`
- `drop_text_search_configuration`
- `add_text_search_configuration_mapping`
- `change_text_search_configuration_mapping`
- `replace_text_search_configuration_mapping`
- `drop_text_search_configuration_mapping`

## TODO

- Add tests
- Enhance (and extract?) functions support
- Check recorder
- Manage schema (`public` is hardcoded)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codeur/activerecord-full_text_search. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/codeur/activerecord-full_text_search/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveRecord::FullTextSearch project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/codeur/activerecord-full_text_search/blob/main/CODE_OF_CONDUCT.md).
