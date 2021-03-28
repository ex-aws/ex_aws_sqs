use Mix.Config

config :ex_aws, :sqs,
  access_key_id: "foo",
  secret_access_key: "bar",
  scheme: "http://",
  host: "localhost",
  port: 9324,
  region: "us-east-1"

config :ex_aws, :hackney_opts,
  follow_redirect: true,
  recv_timeout: 30_000
