# Changelog

## v3.3.0 - 2021-03-28

- Updated min elixir version to 1.7
- Updated ex_aws dependency from "~> 2.0" -> "~> 2.1"
- documentation and formating updates

## v3.2.1 - 2020-04-14

- Updated mix deps for `:saxy` & `:sweet_xml` to be marked optional

## v3.2.0 - 2020-04-13

- Added optional support for [saxy](https://hex.pm/packages/saxy) XML parser
- Saxy parser set as default parser if both `:saxy` and `:sweet_xml` loaded.

## v3.1.0 - 2020-01-22

- Added support for Queue Tags

## v3.0.2 - 2019-11-21

- Improved docs

## v3.0.1 - 2019-11-21

- Updated `sqs_message_attribute_name` typespec for `SQS.receive_message` to match AWS support attributes.

## v3.0.0 - 2019-08-17

- ***BREAKING CHANGE***: Changed queue specific functions to take the QueueUrl instead of the QueueName. Previously the name was used to build the path for the request. This is an anti-pattern according to aws docs and prevents this library from being used with alternative SQS compatible services, like localstack.

## v2.0.1 - 2019-04-11

- Relaxed `:ex_aws` version constraint from `v2.0.0` to `v2.0`

## v2.0.0 - 2017-11-10

- Major Project Split. Please see the main ExAws repository for previous changelogs.
