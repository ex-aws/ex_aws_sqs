use Mix.Config

config :ex_aws, :sqs,
  access_key_id: "foo",
  secret_access_key: "bar",
  scheme: "http://",
  host: "localhost",
  port: 9324,
  region: "us-east-1"
