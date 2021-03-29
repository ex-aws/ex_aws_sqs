# ExAws.SQS

[![Module Version](https://img.shields.io/hexpm/v/ex_aws_sqs.svg)](https://hex.pm/packages/ex_aws_sqs)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_aws_sqs/)
[![Total Download](https://img.shields.io/hexpm/dt/ex_aws_sqs.svg)](https://hex.pm/packages/ex_aws_sqs)
[![License](https://img.shields.io/hexpm/l/ex_aws_sqs.svg)](https://github.com/ex-aws/ex_aws_sqs/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/ex-aws/ex_aws_sqs.svg)](https://github.com/ex-aws/ex_aws_sqs/commits/master)

Service module for [https://github.com/ex-aws/ex_aws](https://github.com/ex-aws/ex_aws).

## Installation

The package can be installed by adding `:ex_aws_sqs` to your list of dependencies in `mix.exs`
along with `:ex_aws` and your preferred JSON codec / HTTP client:

```elixir
def deps do
  [
    {:ex_aws, "~> 2.1"},
    {:ex_aws_sqs, "~> 3.3"},
    {:poison, "~> 3.0"},
    {:hackney, "~> 1.9"},
    {:saxy, "~> 1.1"}, # or {:sweet_xml, "~> 0.6"}
  ]
end
```

## XML Parser

By default `:ex_aws_sqs` will use either `:sweet_xml` or `:saxy` to parse the XML responses from AWS, depending on which is installed. If both libraries are installed then `:saxy` will be choosen first. To explicitly choose either parser then set the `:parser` in your config:
```elixir
config :ex_aws_sqs, parser: ExAws.SQS.SaxyParser
# OR
config :ex_aws_sqs, parser: ExAws.SQS.SweetXmlParser
```

But ensure no other dependencies are setting this value.

## Copyright and License

The MIT License (MIT)

Copyright (c) 2014 CargoSense, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
