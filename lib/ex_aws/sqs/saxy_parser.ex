if Code.ensure_loaded?(Saxy) do
  defmodule ExAws.SQS.SaxyParser do
    @moduledoc false

    alias ExAws.SQS.SaxyCollector, as: Saxy

    @request_id_path ["ResponseMetadata", "RequestId"]

    @list_queues Saxy.build(["ListQueuesResponse"],
                   request_id: @request_id_path,
                   queues: ["ListQueuesResult", "QueueUrl", :many]
                 )

    def parse({:ok, %{body: xml} = resp}, :list_queues) do
      parsed_body = Saxy.parse_string!(xml, @list_queues)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @create_queue Saxy.build(["CreateQueueResponse"],
                    request_id: @request_id_path,
                    queue_url: ["CreateQueueResult", "QueueUrl"]
                  )

    def parse({:ok, %{body: xml} = resp}, :create_queue) do
      parsed_body = Saxy.parse_string!(xml, @create_queue)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @change_message_visibility Saxy.build(["ChangeMessageVisibilityResponse"],
                                 request_id: @request_id_path
                               )

    def parse({:ok, %{body: xml} = resp}, :change_message_visibility) do
      parsed_body = Saxy.parse_string!(xml, @change_message_visibility)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @change_message_visibility_batch Saxy.build(["ChangeMessageVisibilityBatchResponse"],
                                       request_id: @request_id_path,
                                       successes: [
                                         "ChangeMessageVisibilityBatchResult",
                                         "ChangeMessageVisibilityBatchResultEntry",
                                         "Id",
                                         :many
                                       ]
                                     )

    def parse({:ok, %{body: xml} = resp}, :change_message_visibility_batch) do
      parsed_body = Saxy.parse_string!(xml, @change_message_visibility_batch)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @delete_message Saxy.build(["DeleteMessageResponse"],
                      request_id: @request_id_path
                    )

    def parse({:ok, %{body: xml} = resp}, :delete_message) do
      parsed_body = Saxy.parse_string!(xml, @delete_message)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @delete_queue Saxy.build(["DeleteQueueResponse"],
                    request_id: @request_id_path
                  )

    def parse({:ok, %{body: xml} = resp}, :delete_queue) do
      parsed_body = Saxy.parse_string!(xml, @delete_queue)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @delete_message_batch Saxy.build(["DeleteMessageBatchResponse"],
                            request_id: @request_id_path,
                            successes: [
                              "DeleteMessageBatchResult",
                              "DeleteMessageBatchResultEntry",
                              "Id",
                              :many
                            ]
                          )

    def parse({:ok, %{body: xml} = resp}, :delete_message_batch) do
      parsed_body = Saxy.parse_string!(xml, @delete_message_batch)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @get_queue_attributes Saxy.build(["GetQueueAttributesResponse"],
                            request_id: @request_id_path,
                            attributes: [
                              "GetQueueAttributesResult",
                              "Attribute",
                              :many,
                              name: ["Name"],
                              value: ["Value"]
                            ]
                          )

    def parse({:ok, %{body: xml} = resp}, :get_queue_attributes) do
      parsed_body =
        xml
        |> Saxy.parse_string!(@get_queue_attributes)
        |> update_in([:attributes], &attribute_list_to_map(&1, true))

      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @get_queue_url Saxy.build(["GetQueueUrlResponse"],
                     request_id: @request_id_path,
                     queue_url: ["GetQueueUrlResult", "QueueUrl"]
                   )

    def parse({:ok, %{body: xml} = resp}, :get_queue_url) do
      parsed_body = Saxy.parse_string!(xml, @get_queue_url)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @list_dead_letter_source_queues Saxy.build(["ListDeadLetterSourceQueuesResponse"],
                                      request_id: @request_id_path,
                                      queue_urls: [
                                        "ListDeadLetterSourceQueuesResult",
                                        "QueueUrl",
                                        :many
                                      ]
                                    )

    def parse({:ok, %{body: xml} = resp}, :list_dead_letter_source_queues) do
      parsed_body = Saxy.parse_string!(xml, @list_dead_letter_source_queues)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @purge_queue Saxy.build(["PurgeQueueResponse"],
                   request_id: @request_id_path
                 )

    def parse({:ok, %{body: xml} = resp}, :purge_queue) do
      parsed_body = Saxy.parse_string!(xml, @purge_queue)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @remove_permission Saxy.build(["RemovePermissionResponse"],
                         request_id: @request_id_path
                       )

    def parse({:ok, %{body: xml} = resp}, :remove_permission) do
      parsed_body = Saxy.parse_string!(xml, @remove_permission)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @receive_message Saxy.build(["ReceiveMessageResponse"],
                       request_id: @request_id_path,
                       messages: [
                         "ReceiveMessageResult",
                         "Message",
                         :many,
                         message_id: ["MessageId"],
                         receipt_handle: ["ReceiptHandle"],
                         md5_of_body: ["MD5OfBody"],
                         body: ["Body"],
                         attributes: [
                           "Attribute",
                           :many,
                           name: ["Name"],
                           value: ["Value"]
                         ],
                         message_attributes: [
                           "MessageAttribute",
                           :many,
                           name: ["Name"],
                           string_value: ["Value", "StringValue"],
                           binary_value: ["Value", "BinaryValue"],
                           data_type: ["Value", "DataType"]
                         ]
                       ]
                     )

    def parse({:ok, %{body: xml} = resp}, :receive_message) do
      parsed_body = Saxy.parse_string!(xml, @receive_message)

      new_messages =
        parsed_body
        |> Map.get(:messages, [])
        |> Enum.map(fn message ->
          message
          |> fix_attributes([:attributes], &attribute_list_to_map/1)
          |> fix_attributes([:message_attributes], &message_attributes_to_map/1)
        end)

      parsed_body = Map.put(parsed_body, :messages, new_messages)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @send_message Saxy.build(["SendMessageResponse"],
                    request_id: @request_id_path,
                    message_id: ["SendMessageResult", "MessageId"],
                    md5_of_message_body: ["SendMessageResult", "MD5OfMessageBody"],
                    md5_of_message_attributes: ["SendMessageResult", "MD5OfMessageAttributes"]
                  )

    def parse({:ok, %{body: xml} = resp}, :send_message) do
      parsed_body = Saxy.parse_string!(xml, @send_message)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    # https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SendMessageBatch.html#API_SendMessageBatch_ResponseElements
    @send_message_batch Saxy.build(["SendMessageBatchResponse"],
                          request_id: @request_id_path,
                          successes: [
                            "SendMessageBatchResult",
                            "SendMessageBatchResultEntry",
                            :many,
                            id: ["Id"],
                            message_id: ["MessageId"],
                            md5_of_message_body: ["MD5OfMessageBody"],
                            md5_of_message_attributes: ["MD5OfMessageAttributes"]
                          ],
                          # https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_BatchResultErrorEntry.html
                          failures: [
                            "SendMessageBatchResult",
                            "BatchResultErrorEntry",
                            :many,
                            code: ["Code"],
                            id: ["Id"],
                            message: ["Message"],
                            # FIXME Cast to boolean
                            sender_fault: ["SenderFault"]
                          ]
                        )

    def parse({:ok, %{body: xml} = resp}, :send_message_batch) do
      parsed_body = Saxy.parse_string!(xml, @send_message_batch)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @set_queue_attributes Saxy.build(["SetQueueAttributesResponse"],
                            request_id: @request_id_path
                          )

    def parse({:ok, %{body: xml} = resp}, :set_queue_attributes) do
      parsed_body = Saxy.parse_string!(xml, @set_queue_attributes)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @list_queue_tags Saxy.build(["ListQueueTagsResponse", "ListQueueTagsResult"],
                       request_id: @request_id_path,
                       tags: ["Tag", :many, key: ["Key"], value: ["Value"]]
                     )

    def parse({:ok, %{body: xml} = resp}, :list_queue_tags) do
      parsed_body = Saxy.parse_string!(xml, @list_queue_tags)
      {:ok, Map.put(resp, :body, parsed_body)}
    end

    @error_response Saxy.build(["ErrorResponse"],
                      request_id: ["RequestId"],
                      type: ["Error", "Type"],
                      code: ["Error", "Code"],
                      message: ["Error", "Message"],
                      detail: ["Error", "Detail"]
                    )

    def parse({:error, {type, http_status_code, %{body: xml}}}, _) do
      parsed_body = Saxy.parse_string!(xml, @error_response)
      {:error, {type, http_status_code, parsed_body}}
    end

    def parse(val, _), do: val

    defp message_attributes_to_map(list_of_message_attribtues) do
      list_of_message_attribtues
      |> Enum.reduce(%{}, fn %{name: name, data_type: data_type} = attr, acc ->
        case parse_attribute_value(data_type, attr) do
          ^attr ->
            Map.put(acc, name, attr)

          parsed ->
            Map.put(acc, name, Map.put(attr, :value, parsed))
        end
      end)
    end

    defp fix_attributes(parsed_body, attribute_path, fixup_fn) do
      case get_in(parsed_body, attribute_path) do
        nil ->
          parsed_body

        [] ->
          parsed_body

        v when is_list(v) ->
          update_in(parsed_body, attribute_path, fixup_fn)
      end
    end

    defp parse_attribute_value(<<"String", _::binary>>, %{string_value: string_value}) do
      string_value
    end

    defp parse_attribute_value(<<"Binary", _::binary>>, %{binary_value: b64_encoded}) do
      case Base.decode64(b64_encoded) do
        {:ok, decoded} ->
          decoded

        _ ->
          b64_encoded
      end
    end

    defp parse_attribute_value(<<"Number", _::binary>>, %{string_value: string_value}) do
      try do
        String.to_integer(string_value)
      rescue
        ArgumentError ->
          try do
            String.to_float(string_value)
          rescue
            ArgumentError ->
              string_value
          end
      end
    end

    defp parse_attribute_value(_data_type, other) do
      other
    end

    defp attribute_list_to_map(list_of_maps, convert_to_atoms \\ false)

    defp attribute_list_to_map(list_of_maps, convert_to_atoms) do
      Enum.reduce(list_of_maps, %{}, fn %{name: name, value: val}, acc ->
        attribute_name =
          name
          |> Macro.underscore()

        attribute_name =
          if convert_to_atoms do
            String.to_atom(attribute_name)
          else
            attribute_name
          end

        parsed_val = try_cast(attribute_name, val)

        Map.put(acc, attribute_name, parsed_val)
      end)
    end

    def try_cast(_name, "true"), do: true
    def try_cast(_name, "false"), do: false

    def try_cast(name, string_val) do
      case name do
        "message_group_id" ->
          string_val

        _ ->
          try do
            String.to_integer(string_val)
          rescue
            ArgumentError ->
              string_val
          end
      end
    end
  end
end
