defmodule ExAws.SQSIntegrationTest do
  use ExUnit.Case, async: true
  alias ExAws.SQS

  @queue_name "test_queue"

  setup_all do
    ExAws.Config.new(:sqs)

    {:ok, %{body: %{queue_url: queue_url}}} = SQS.create_queue(@queue_name, [], %{tag1: "value"}) |> ExAws.request()

    [queue_url: queue_url]
  end

  test "add_permission/2" do
    assert {:ok, %{body: _}} =
             SQS.add_permission(@queue_name, "TestAddPermission") |> ExAws.request()
  end

  test "add_permission/3" do
    assert {:ok, %{body: _}} =
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

    assert {:ok, %{body: %{request_id: _}}} =
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

    assert {:ok, %{body: %{request_id: _, successes: successes}}} =
             SQS.change_message_visibility_batch(context.queue_url, messages_payload)
             |> ExAws.request()

    assert successes |> Enum.sort() == Enum.map(messages, & &1.message_id) |> Enum.sort()
  end

  test "create_queue/1" do
    queue_name = "test_queue_2"

    assert {:ok, %{body: %{queue_url: queue_url}}} =
             SQS.create_queue(queue_name) |> ExAws.request()

    assert queue_url |> String.contains?(queue_name)
  end

  test "create_queue/2" do
    queue_name = "test_queue_3"

    assert {:ok, %{body: %{queue_url: queue_url}}} =
             SQS.create_queue(queue_name, receive_message_wait_time_seconds: 20)
             |> ExAws.request()

    assert queue_url |> String.contains?(queue_name)
  end

  test "create_queue/3" do
    queue_name = "test_queue_with_tags"

    assert {:ok, %{body: %{queue_url: queue_url}}} =
             SQS.create_queue(queue_name, %{tag1: "foo", tag2: "bar"})
             |> ExAws.request()

    assert queue_url |> String.contains?(queue_name)
  end

  test "delete_message/2", context do
    assert {:ok, %{body: %{request_id: _}}} =
             SQS.delete_message(context.queue_url, "a_receipt_handle") |> ExAws.request()
  end

  test "delete_message_batch/2", context do
    assert {:ok, _} =
             SQS.delete_message_batch(context.queue_url, [
               %{
                 id: "message_1",
                 receipt_handle: "a_receipt_handle"
               },
               %{
                 id: "message_2",
                 receipt_handle: "another_receipt_handle"
               }
             ])
             |> ExAws.request()
  end

  test "delete_queue/1" do
    {:ok, %{body: %{queue_url: queue_url}}} = SQS.create_queue("test_queue_4") |> ExAws.request()

    assert {:ok, %{body: %{request_id: _}}} = SQS.delete_queue(queue_url) |> ExAws.request()
  end

  test "get_queue_attributes/1", context do
    assert {:ok, %{body: %{attributes: _, request_id: _}}} =
             SQS.get_queue_attributes(context.queue_url) |> ExAws.request()
  end

  test "get_queue_attributes/2", context do
    assert {:ok, %{body: %{attributes: _, request_id: _}}} =
             SQS.get_queue_attributes(context.queue_url, [
               :visibility_timeout,
               :message_retention_period
             ])
             |> ExAws.request()
  end

  test "get_queue_url/1" do
    assert {:ok, %{body: %{queue_url: queue_url}}} =
             SQS.get_queue_url(@queue_name) |> ExAws.request()

    assert queue_url |> String.contains?(@queue_name)
  end

  test "get_queue_url/2" do
    assert {:ok, %{body: %{queue_url: queue_url}}} =
             SQS.get_queue_url(@queue_name, queue_owner_aws_account_id: "foo") |> ExAws.request()

    assert queue_url |> String.contains?(@queue_name)
  end

  # This is skipped because elasticmq does not support this action which is used for testing, this 
  # Does work against AWS SQS directly
  @tag :skip
  test "list_dead_letter_source_queues/1", context do
    assert {:ok, _} = SQS.list_dead_letter_source_queues(context.queue_url) |> ExAws.request()
  end

  test "list_queues/0" do
    assert {:ok, %{body: %{queues: queues}}} = SQS.list_queues() |> ExAws.request()
    assert is_list(queues)
  end

  test "list_queues/1" do
    assert {:ok, %{body: %{queues: queues}}} =
             SQS.list_queues(queue_name_prefix: "prefix") |> ExAws.request()

    assert is_list(queues)
  end

  test "list_queue_tags/1", context do
    assert {:ok, %{body: %{tags: tags}}} = SQS.list_queue_tags(context.queue_url) |> ExAws.request()
    assert is_list(tags)
  end

  test "purge_queue/1", context do
    assert {:ok, %{body: %{request_id: _}}} =
             SQS.purge_queue(context.queue_url) |> ExAws.request()
  end

  test "receive_message/1", context do
    assert {:ok, %{body: %{messages: messages}}} =
             SQS.receive_message(context.queue_url) |> ExAws.request()

    assert is_list(messages)
  end

  test "receive_message/2", context do
    assert {:ok, %{body: %{messages: messages}}} =
             SQS.receive_message(context.queue_url,
               attribute_names: :all,
               max_number_of_messages: 5
             )
             |> ExAws.request()

    assert is_list(messages)
  end

  # This is skipped because elasticmq does not support this action which is used for testing, this 
  # Does work against AWS SQS directly
  @tag :skip
  test "remove_permission/2", context do
    SQS.add_permission(@queue_name, "TestAddPermission") |> ExAws.request()

    assert {:ok, _} =
             SQS.remove_permission(context.queue_url, "TestAddPermission") |> ExAws.request()
  end

  test "send_message/2", context do
    assert {:ok,
            %{
              body: %{
                md5_of_message_attributes: _,
                md5_of_message_body: _,
                message_id: _,
                request_id: _
              }
            }} = SQS.send_message(context.queue_url, "lorem ipsum") |> ExAws.request()
  end

  test "send_message/3", context do
    assert {:ok,
            %{
              body: %{
                md5_of_message_attributes: _,
                md5_of_message_body: _,
                message_id: _,
                request_id: _
              }
            }} =
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
    {:ok, %{body: %{failures: _, request_id: _, successes: successes}}} =
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

    assert ["test_message_1", "test_message_2"] == successes |> Enum.map(& &1.id) |> Enum.sort()
  end

  test "set_queue_attributes/1", context do
    assert {:ok, %{body: %{request_id: _}}} =
             SQS.set_queue_attributes(context.queue_url) |> ExAws.request()
  end

  test "set_queue_attributes/2", context do
    assert {:ok, %{body: %{request_id: _}}} =
             SQS.set_queue_attributes(context.queue_url, visibility_timeout: 10)
             |> ExAws.request()
  end

  test "tag_queue/2", context do
    assert {:ok, _} = SQS.tag_queue(context.queue_url, %{foo: "bar"}) |> ExAws.request()
  end

  test "untag_queue/2", context do
    assert {:ok, _} = SQS.untag_queue(context.queue_url, [:foo, "foo2"]) |> ExAws.request()
  end
end
