defmodule ExAws.SQSIntegrationTest do
  use ExUnit.Case, async: true
  alias ExAws.SQS

  @queue_name "test_queue"

  setup_all do
    ExAws.Config.new(:sqs)

    {:ok, %{body: %{queue_url: queue_url}}} = SQS.create_queue(@queue_name) |> ExAws.request()

    [queue_url: queue_url]
  end

  test "add_permission/2" do
    assert {:ok, _} = SQS.add_permission(@queue_name, "TestAddPermission") |> ExAws.request()
  end

  test "add_permission/3" do
    assert {:ok, _} =
             SQS.add_permission(@queue_name, "TestAddPermission2", %{
               "681962096817" => :all,
               "071669896281" => [:send_message, :receive_message]
             })
             |> ExAws.request()
  end

  test "change_message_visibility/3", context do
    SQS.send_message(context.queue_url, "lorem ipsum") |> ExAws.request()

    {:ok, %{body: %{messages: messages}}} =
      SQS.receive_message(context.queue_url) |> ExAws.request()

    receipt_handle = List.first(messages).receipt_handle

    assert {:ok, _} =
             SQS.change_message_visibility(context.queue_url, receipt_handle, 300)
             |> ExAws.request()
  end

  test "change_message_visibility_batch/2", context do
    SQS.send_message_batch(
      context.queue_url,
      [
        [
          id: "message_1",
          message_body: "This is the first message body.",
          message_attributes: [
            %{
              name: "TestAnotherStringAttribute",
              data_type: :string,
              value: "still testing!"
            }
          ]
        ],
        [
          id: "message_2",
          message_body: "This is the second message body.",
          message_attributes: [
            %{
              name: "TestAnotherStringAttribute",
              data_type: :string,
              value: "still testing!"
            }
          ]
        ]
      ]
    )
    |> ExAws.request()

    {:ok, %{body: %{messages: messages}}} =
      SQS.receive_message(context.queue_url, attribute_names: :all, max_number_of_messages: 2)
      |> ExAws.request()

    messages_payload =
      messages
      |> Enum.map(fn message ->
        %{
          id: message.message_id,
          receipt_handle: message.receipt_handle,
          visibility_timeout: 600
        }
      end)

    assert {:ok, _} =
             SQS.change_message_visibility_batch(context.queue_url, messages_payload)
             |> ExAws.request()
  end

  test "create_queue/1" do
    assert {:ok, %{body: %{queue_url: _}}} =
             SQS.create_queue("yet_another_test_queue") |> ExAws.request()
  end

  test "create_queue/2" do
    assert {:ok, %{body: %{queue_url: _}}} =
             SQS.create_queue("another_queue2", receive_message_wait_time_seconds: 20)
             |> ExAws.request()
  end

  test "delete_message/2", context do
    assert {:ok, _} =
             SQS.delete_message(
               context.queue_url,
               "AQEB0aw+z96sMOUWLQuIzA7nPHS7zUOIRlV0OEqvDoKtNcHxSVDQEfY0gBOJKGcnyTvIUncpimPv0CfQDFbwmdU9E00793cP19Bx8BqzuS0sNrARyY4M4xVi7ceVYHMSNU1uyF/+sK6u8yAGnsbsgmPg4AUs5oapv5Qawiq5HJGgH3cmRPy5/IW+b9W6HVy//uNzejbIcAjQX58Dd79D4AGb9Iu4dqfEVK7zo5BCTy+pz9hqGf5MT3jkrd5umjwGdrg3sVBYhrLjmgaqftON8JclkmrUJk0LzPwQ4DdpT8oz5mh7VzAjRXkIA0IQ8PGFFGPMIb8gWNzJ4KA4/OYlnDYyGw=="
             )
             |> ExAws.request()
  end

  test "delete_message_batch/2", context do
    assert {:ok, _} =
             SQS.delete_message_batch(context.queue_url, [
               %{
                 id: "message_1",
                 receipt_handle:
                   "AQEBlA6/i+8F3P6lA7y3msc8dINnF+b3VgTX71nMWw7VvbHc8mdGFyZjVAVMH/rg6Vyc00O2Tl2ZyKn8IPUiy6n44ipop+xb33XNU/cABvVWZogNN95b9mmR6RuSA0dcVmFL02TwZDpg7cMOWNhYThEp+a5atsG85PX7V6q9zBklltBSQnT6r9QSngnv2m1C23jfFYow0oy86cofp0mQ4z5ez9bWmlHa4XfpZUpP2KVlBCDgyR0tQQRGt170foph32Cg+Bp6RRv9Tyo7aVWqM4OT/CHTJ0ZPiAYoH8MYFxjUaqoeKhUwDFq36trQxrBq9BfBj+hrzEtDQdxcNZM2pZi2xQ=="
               },
               %{
                 id: "message_2",
                 receipt_handle:
                   "AQEBc8vuFKIpTF3ESXTpxc2+vARUXHpGzup9YwTMD7Alibe/z/yXEPaXY4ZtTUvInYfEazLhughdoLGSEh1SDPsIdDB9Os8D84xHmtXelswA7FBXEdNunRk4wg6Zi4jgjEy3Kyy9cGpiZwRxw4Vy4PrK7H0BbH07k+mVby8P8B9m97GO/w666/zU46QpFB6jhi7L0d76AW16/PMzEBbDB6zUvXiYUAMmxvdppYrcYqb22K0gWvZsL1Dogr592k/fA1W2oF1YsjTSn9FjYr/q5XK1Z1Lvvmh3/20D5U0qjnFd4wg9MlVp8zrBg2mNoVl6QEHPNP/zA+dZg2d/6SSgEdI1hQ=="
               }
             ])
             |> ExAws.request()
  end

  test "delete_queue/1" do
    {:ok, %{body: %{queue_url: queue_url}}} =
      SQS.create_queue("another_test_queue") |> ExAws.request()

    assert {:ok, _} = SQS.delete_queue(queue_url) |> ExAws.request()
  end

  test "get_queue_attributes/1", context do
    assert {:ok, _} = SQS.get_queue_attributes(context.queue_url) |> ExAws.request()
  end

  test "get_queue_attributes/2", context do
    assert {:ok, _} =
             SQS.get_queue_attributes(context.queue_url, [
               :visibility_timeout,
               :message_retention_period
             ])
             |> ExAws.request()
  end

  test "get_queue_url/1" do
    assert {:ok, %{body: %{queue_url: _}}} = SQS.get_queue_url(@queue_name) |> ExAws.request()
  end

  test "get_queue_url/2" do
    assert {:ok, %{body: %{queue_url: _}}} =
             SQS.get_queue_url(@queue_name, queue_owner_aws_account_id: "foo") |> ExAws.request()
  end

  @tag :skip
  test "list_dead_letter_source_queues/1", context do
    assert {:ok, _} = SQS.list_dead_letter_source_queues(context.queue_url) |> ExAws.request()
  end

  test "list_queues/0" do
    assert {:ok, %{body: %{queues: _}}} = SQS.list_queues() |> ExAws.request()
  end

  test "list_queues/1" do
    assert {:ok, %{body: %{queues: _}}} =
             SQS.list_queues(queue_name_prefix: "prefix") |> ExAws.request()
  end

  @tag :skip
  test "list_queue_tags NOT IMPLEMENTED"

  test "purge_queue/1", context do
    assert {:ok, _} = SQS.purge_queue(context.queue_url) |> ExAws.request()
  end

  test "receive_message/1", context do
    assert {:ok, _} = SQS.receive_message(context.queue_url) |> ExAws.request()
  end

  test "receive_message/2", context do
    assert {:ok, _} =
             SQS.receive_message(context.queue_url,
               attribute_names: :all,
               max_number_of_messages: 5
             )
             |> ExAws.request()
  end

  @tag :skip
  test "remove_permission/2", context do
    SQS.add_permission(@queue_name, "TestAddPermission") |> ExAws.request()

    assert {:ok, _} =
             SQS.remove_permission(context.queue_url, "TestAddPermission") |> ExAws.request()
  end

  test "send_message/2", context do
    assert {:ok, _} = SQS.send_message(context.queue_url, "lorem ipsum") |> ExAws.request()
  end

  test "send_message/3", context do
    assert {:ok, _} =
             SQS.send_message(
               context.queue_url,
               "This is the message body.",
               delay_seconds: 30,
               message_attributes: [
                 %{
                   name: "TestStringAttribute",
                   data_type: :string,
                   value: "testing!"
                 }
               ]
             )
             |> ExAws.request()
  end

  test "send_message_batch/2", context do
    assert {:ok, _} =
             SQS.send_message_batch(
               context.queue_url,
               [
                 [
                   id: "test_message_1",
                   message_body: "This is the message body.",
                   delay_seconds: 30,
                   message_attributes: [
                     %{
                       name: "TestStringAttribute",
                       data_type: :string,
                       value: "testing!"
                     }
                   ]
                 ],
                 [
                   id: "test_message_2",
                   message_body: "This is the second message body.",
                   message_attributes: [
                     %{
                       name: "TestAnotherStringAttribute",
                       data_type: :string,
                       value: "still testing!"
                     }
                   ]
                 ]
               ]
             )
             |> ExAws.request()
  end

  test "set_queue_attributes/1", context do
    assert {:ok, _} = SQS.set_queue_attributes(context.queue_url) |> ExAws.request()
  end

  test "set_queue_attributes/2", context do
    assert {:ok, _} =
             SQS.set_queue_attributes(context.queue_url, visibility_timeout: 10)
             |> ExAws.request()
  end

  @tag :skip
  test "tag_queue NOT IMPLEMENTED"

  @tag :skip
  test "untag_queue NOT IMPLEMENTED"
end
