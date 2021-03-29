defmodule ExAws.SQS do
  @moduledoc """
  Operations on AWS SQS.
  """

  @type sqs_permission ::
          :send_message
          | :receive_message
          | :delete_message
          | :change_message_visibility
          | :get_queue_attributes
  @type sqs_acl :: %{binary => :all | [sqs_permission, ...]}

  # Values taken from
  # https://github.com/aws/aws-sdk-go/blob/075b1d697ba8dbab8bb841042fa12d43192d0153/models/apis/sqs/2012-11-05/api-2.json#L752.
  # They differ from the list of allowed values described in the aws-cli (`aws sqs receive-message help`) or on
  # https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ReceiveMessage.html, but they match the
  # ones described in prose under the respective section.
  @type sqs_message_attribute_name ::
          :sender_id
          | :sent_timestamp
          | :approximate_receive_count
          | :approximate_first_receive_timestamp
          | :sequence_number
          | :message_deduplication_id
          | :message_group_id
          | :aws_trace_header

  @type sqs_queue_attribute_name ::
          :policy
          | :visibility_timeout
          | :maximum_message_size
          | :message_retention_period
          | :approximate_number_of_messages
          | :approximate_number_of_messages_not_visible
          | :created_timestamp
          | :last_modified_timestamp
          | :queue_arn
          | :approximate_number_of_messages_delayed
          | :delay_seconds
          | :receive_message_wait_time_seconds
          | :redrive_policy
          | :fifo_queue
          | :content_based_deduplication
  @type visibility_timeout :: 0..43200
  @type queue_attributes :: [
          {:policy, binary}
          | {:visibility_timeout, visibility_timeout}
          | {:maximum_message_size, 1024..262_144}
          | {:message_retention_period, 60..1_209_600}
          | {:approximate_number_of_messages, binary}
          | {:approximate_number_of_messages_not_visible, binary}
          | {:created_timestamp, binary}
          | {:last_modified_timestamp, binary}
          | {:queue_arn, binary}
          | {:approximate_number_of_messages_delayed, binary}
          | {:delay_seconds, 0..900}
          | {:receive_message_wait_time_seconds, 0..20}
          | {:redrive_policy, binary}
          | {:fifo_queue, boolean}
          | {:content_based_deduplication, boolean}
          | {:kms_master_key_id, binary}
          | {:kms_data_key_reuse_period_seconds, 60..86400}
        ]
  @type sqs_message_attribute :: %{
          :name => binary,
          :data_type => :string | :binary | :number,
          :custom_type => binary | none,
          :value => binary | number
        }

  @doc """
  Adds a permission with the provided label to the Queue
  for a specific action for a specific account.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_AddPermission.html)
  """
  @spec add_permission(queue_url :: binary, label :: binary, permissions :: sqs_acl) ::
          ExAws.Operation.Query.t()
  def add_permission(queue_url, label, permissions \\ %{}) do
    params =
      permissions
      |> format_permissions
      |> Map.put("Label", label)

    request(queue_url, :add_permission, params)
  end

  @doc """
  Extends the read lock timeout for the specified message from
  the specified queue to the specified value.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ChangeMessageVisibility.html)
  """
  @spec change_message_visibility(
          queue_url :: binary,
          receipt_handle :: binary,
          visibility_timeout :: visibility_timeout
        ) :: ExAws.Operation.Query.t()
  def change_message_visibility(queue_url, receipt_handle, visibility_timeout) do
    request(queue_url, :change_message_visibility, %{
      "ReceiptHandle" => receipt_handle,
      "VisibilityTimeout" => visibility_timeout
    })
  end

  @doc """
  Extends the read lock timeout for a batch of 1..10 messages.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ChangeMessageVisibilityBatch.html)
  """
  @type message_visibility_batch_item :: %{
          :id => binary,
          :receipt_handle => binary,
          :visibility_timeout => visibility_timeout
        }
  @spec change_message_visibility_batch(
          queue_url :: binary,
          opts :: [message_visibility_batch_item, ...]
        ) :: ExAws.Operation.Query.t()
  def change_message_visibility_batch(queue_url, messages) do
    params =
      messages
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {message, index}, params ->
        Map.merge(params, format_batch_visibility_change(message, index))
      end)

    request(queue_url, :change_message_visibility_batch, params)
  end

  @doc """
  Create queue.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_CreateQueue.html)

  ## Attributes

    * `:delay_seconds` - The length of time, in seconds, for which the delivery of all messages in the queue is delayed. Valid values: An integer from 0 to 900 seconds (15 minutes). Default: 0.

    * `:maximum_message_size` - The limit of how many bytes a message can contain before Amazon SQS rejects it. Valid values: An integer from 1,024 bytes (1 KiB) to 262,144 bytes (256 KiB). Default: 262,144 (256 KiB).

    * `:message_retention_period` - The length of time, in seconds, for which Amazon SQS retains a message. Valid values: An integer from 60 seconds (1 minute) to 1,209,600 seconds (14 days). Default: 345,600 (4 days).

    * `:policy` - The queue's policy. A valid AWS policy. For more information about policy structure, see [Overview of AWS IAM Policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/PoliciesOverview.html) in the Amazon IAM User Guide.

    * `:receive_message_wait_time_seconds` - The length of time, in seconds, for which a [ReceiveMessage](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ReceiveMessage.html) action waits for a message to arrive. Valid values: An integer from 0 to 20 (seconds). Default: 0.

    * `:redrive_policy` - The string that includes the parameters for the dead-letter queue functionality of the source queue as a JSON object. For more information about the redrive policy and dead-letter queues, see [Using Amazon SQS Dead-Letter Queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html) in the Amazon Simple Queue Service Developer Guide.
      * `deadLetterTargetArn` – The Amazon Resource Name (ARN) of the dead-letter queue to which Amazon SQS moves messages after the value of maxReceiveCount is exceeded.

      * `maxReceiveCount` – The number of times a message is delivered to the source queue before being moved to the dead-letter queue. When the ReceiveCount for a message exceeds the maxReceiveCount for a queue, Amazon SQS moves the message to the dead-letter-queue.

      *Note*

      The dead-letter queue of a FIFO queue must also be a FIFO queue. Similarly, the dead-letter queue of a standard queue must also be a standard queue.

    * `:visibility_timeout` - The visibility timeout for the queue, in seconds. Valid values: An integer from 0 to 43,200 (12 hours). Default: 30. For more information about the visibility timeout, see [Visibility Timeout](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html) in the Amazon Simple Queue Service Developer Guide.

    * `:fifo_queue` - Designates a queue as FIFO. Valid values: true, false. If you don't specify the FifoQueue attribute, Amazon SQS creates a standard queue. You can provide this attribute only during queue creation. You can't change it for an existing queue. When you set this attribute, you must also provide the MessageGroupId for your messages explicitly.
      For more information, see [FIFO Queue Logic](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues.html#FIFO-queues-understanding-logic) in the Amazon Simple Queue Service Developer Guide.

    * `:content_based_deduplication` - Enables content-based deduplication. Valid values: true, false. For more information, see [Exactly-Once Processing](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues.html#FIFO-queues-exactly-once-processing) in the Amazon Simple Queue Service Developer Guide.

    * `:kms_master_key_id` - The ID of an AWS-managed customer master key (CMK) for Amazon SQS or a custom CMK. For more information, see [Key Terms](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-server-side-encryption.html#sqs-sse-key-terms). While the alias of the AWS-managed CMK for Amazon SQS is always alias/aws/sqs, the alias of a custom CMK can, for example, be alias/MyAlias . For more examples, see [KeyId](https://docs.aws.amazon.com/kms/latest/APIReference/API_DescribeKey.html#API_DescribeKey_RequestParameters) in the AWS Key Management Service API Reference.

    * `:kms_data_key_reuse_period_seconds` - The length of time, in seconds, for which Amazon SQS can reuse a [data key](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#data-keys) to encrypt or decrypt messages before calling AWS KMS again. An integer representing seconds, between 60 seconds (1 minute) and 86,400 seconds (24 hours). Default: 300 (5 minutes). A shorter time period provides better security but results in more calls to KMS which might incur charges after Free Tier. For more information, see [How Does the Data Key Reuse Period Work?](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-server-side-encryption.html#sqs-how-does-the-data-key-reuse-period-work).

  """
  @spec create_queue(queue_name :: binary) :: ExAws.Operation.Query.t()
  @spec create_queue(queue_name :: binary, queue_attributes :: queue_attributes) ::
          ExAws.Operation.Query.t()
  def create_queue(queue_name, attributes \\ [], tags \\ %{}) do
    params =
      attributes
      |> build_attrs
      |> add_tags_to_params(tags)
      |> Map.put("QueueName", queue_name)

    request(nil, :create_queue, params)
  end

  @doc """
  Delete a message from a SQS Queue

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_DeleteMessage.html)
  """
  @spec delete_message(queue_url :: binary, receipt_handle :: binary) :: ExAws.Operation.Query.t()
  def delete_message(queue_url, receipt_handle) do
    request(queue_url, :delete_message, %{"ReceiptHandle" => receipt_handle})
  end

  @doc """
  Deletes a list of messages from a SQS Queue in a single request

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_DeleteMessageBatch.html)
  """
  @type delete_message_batch_item :: %{
          :id => binary,
          :receipt_handle => binary
        }
  @spec delete_message_batch(
          queue_url :: binary,
          message_receipts :: [delete_message_batch_item, ...]
        ) :: ExAws.Operation.Query.t()
  def delete_message_batch(queue_url, messages) do
    params =
      messages
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {message, index}, params ->
        Map.merge(params, format_batch_deletion(message, index))
      end)

    request(queue_url, :delete_message_batch, params)
  end

  @doc """
  Delete a queue

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_DeleteQueue.html)
  """
  @spec delete_queue(queue_url :: binary) :: ExAws.Operation.Query.t()
  def delete_queue(queue_url) do
    request(queue_url, :delete_queue, %{})
  end

  @doc """
  Gets attributes of a SQS Queue

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_GetQueueAttributes.html)
  """
  @spec get_queue_attributes(queue_url :: binary) :: ExAws.Operation.Query.t()
  @spec get_queue_attributes(
          queue_url :: binary,
          attribute_names :: :all | [sqs_queue_attribute_name, ...]
        ) :: ExAws.Operation.Query.t()
  def get_queue_attributes(queue_url, attributes \\ :all) do
    params =
      attributes
      |> format_queue_attributes

    request(queue_url, :get_queue_attributes, params)
  end

  @doc """
  Get queue URL

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_GetQueueUrl.html)

  ## Options

    * `:queue_owner_aws_account_id` -  The AWS account ID of the account that created the queue.
  """
  @spec get_queue_url(queue_name :: binary) :: ExAws.Operation.Query.t()
  @spec get_queue_url(queue_name :: binary, opts :: [queue_owner_aws_account_id: binary]) ::
          ExAws.Operation.Query.t()
  def get_queue_url(queue_name, opts \\ []) do
    params =
      opts
      |> format_regular_opts
      |> Map.put("QueueName", queue_name)

    request(nil, :get_queue_url, params)
  end

  @doc """
  Retrieves the dead letter source queues for a given SQS Queue

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ListDeadLetterSourceQueues.html)
  """
  @spec list_dead_letter_source_queues(queue_url :: binary) :: ExAws.Operation.Query.t()
  def list_dead_letter_source_queues(queue_url) do
    request(queue_url, :list_dead_letter_source_queues, %{})
  end

  @doc """
  Retrieves a list of all the SQS Queues

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ListQueues.html)

  ## Options

    * `:queue_name_prefix` - A string to use for filtering the list results. Only those queues whose name begins with the specified string are returned.
      Queue URLs and names are case-sensitive.
  """
  @spec list_queues() :: ExAws.Operation.Query.t()
  @spec list_queues(opts :: [queue_name_prefix: binary]) :: ExAws.Operation.Query.t()
  def list_queues(opts \\ []) do
    params =
      opts
      |> format_regular_opts

    request(nil, :list_queues, params)
  end

  @doc """
  Purge all messages in a SQS Queue

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_PurgeQueue.html)
  """
  @spec purge_queue(queue_url :: binary) :: ExAws.Operation.Query.t()
  def purge_queue(queue_url) do
    request(queue_url, :purge_queue, %{})
  end

  @type receive_message_opts :: [
          {:attribute_names, :all | [sqs_message_attribute_name, ...]}
          | {:message_attribute_names, :all | [String.Chars.t(), ...]}
          | {:max_number_of_messages, 1..10}
          | {:visibility_timeout, 0..43200}
          | {:wait_time_seconds, 0..20}
          | {:receive_request_attempt_id, String.t()}
        ]

  @doc """
  Read messages from a SQS Queue

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ReceiveMessage.html)

  ## Options

    * `:attribute_names` - `:all` or a list of `AttributeNames` to include in the response. Valid attributes are:
    [:sender_id, :sent_timestamp, :approximate_receive_count, :approximate_first_receive_timestamp, :sequence_number, :message_deduplication_id, :message_group_id, :aws_trace_header]

    * `:message_attribute_names` - List of message attributes to include.

      * The name can contain alphanumeric characters and the underscore (_), hyphen (-), and period (.).

      * The name is case-sensitive and must be unique among all attribute names for the message.

      * The name must not start with AWS-reserved prefixes such as AWS. or Amazon. (or any casing variants).

      * The name must not start or end with a period (.), and it should not have periods in succession (..).

      * The name can be up to 256 characters long.

      When using ReceiveMessage, you can send a list of attribute names to receive, or you can return all of the attributes by specifying All or .* in your request. You can also use all message attributes starting with a prefix, for example bar.*.

    * `:max_number_of_messages` - The maximum number of messages to return. Amazon SQS never returns more messages than this value (however, fewer messages might be returned). Valid values: 1 to 10. Default: 1.

    * `:visibility_timeout` - The duration (in seconds) that the received messages are hidden from subsequent retrieve requests after being retrieved by a ReceiveMessage request.

    * `:wait_time_seconds` - The duration (in seconds) for which the call waits for a message to arrive in the queue before returning. If a message is available, the call returns sooner than WaitTimeSeconds. If no messages are available and the wait time expires, the call returns successfully with an empty list of messages.

    * `:receive_request_attempt_id` - This parameter applies only to FIFO (first-in-first-out) queues.

      The token used for deduplication of ReceiveMessage calls. If a networking issue occurs after a ReceiveMessage action, and instead of a response you receive a generic error, it is possible to retry the same action with an identical ReceiveRequestAttemptId to retrieve the same set of messages, even if their visibility timeout has not yet expired.
  """
  @spec receive_message(queue_url :: binary) :: ExAws.Operation.Query.t()
  @spec receive_message(queue_url :: binary, opts :: receive_message_opts) ::
          ExAws.Operation.Query.t()
  def receive_message(queue_url, opts \\ []) do
    {attrs, opts} =
      opts
      |> Keyword.pop(:attribute_names, [])

    {message_attrs, opts} =
      opts
      |> Keyword.pop(:message_attribute_names, [])

    params =
      attrs
      |> format_queue_attributes
      |> Map.merge(format_message_attributes(message_attrs))
      |> Map.merge(format_regular_opts(opts))

    request(queue_url, :receive_message, params)
  end

  @doc """
  Removes permission with the given label from the Queue

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_RemovePermission.html)
  """
  @spec remove_permission(queue_url :: binary, label :: binary) :: ExAws.Operation.Query.t()
  def remove_permission(queue_url, label) do
    request(queue_url, :remove_permission, %{"Label" => label})
  end

  @type sqs_message_opts :: [
          {:delay_seconds, 0..900}
          | {:message_attributes, sqs_message_attribute | [sqs_message_attribute, ...]}
          | {:message_deduplication_id, binary}
          | {:message_group_id, binary}
        ]

  @doc """
  Send a message to a SQS Queue

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SendMessage.html)

  ## Options

    * `:delay_seconds` - The length of time, in seconds, for which to delay a specific message. Valid values: 0 to 900. Maximum: 15 minutes. Messages with a positive DelaySeconds value become available for processing after the delay period is finished. If you don't specify a value, the default value for the queue applies.

    * `:message_attributes` - Each message attribute consists of a Name, Type, and Value. For more information, see [Amazon SQS Message Attributes](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-message-attributes.html) in the Amazon Simple Queue Service Developer Guide.

    * `:message_deduplication_id` - This parameter applies only to FIFO (first-in-first-out) queues.

    * `:message_group_id` - This parameter applies only to FIFO (first-in-first-out) queues.
  """
  @spec send_message(queue_url :: binary, message_body :: binary) :: ExAws.Operation.Query.t()
  @spec send_message(queue_url :: binary, message_body :: binary, opts :: sqs_message_opts) ::
          ExAws.Operation.Query.t()
  def send_message(queue_url, message, opts \\ []) do
    {attrs, opts} =
      opts
      |> Keyword.pop(:message_attributes, [])

    attrs = attrs |> build_message_attrs

    params =
      opts
      |> format_regular_opts
      |> Map.merge(attrs)
      |> Map.put("MessageBody", message)

    request(queue_url, :send_message, params)
  end

  @type sqs_batch_message ::
          binary
          | [
              {:id, binary}
              | {:message_body, binary}
              | {:delay_seconds, 0..900}
              | {:message_attributes, sqs_message_attribute | [sqs_message_attribute, ...]}
              | {:message_deduplication_id, binary}
              | {:message_group_id, binary}
            ]

  @doc """
  Send up to 10 messages to a SQS Queue in a single request.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SendMessageBatch.html)
  """
  @spec send_message_batch(queue_url :: binary, messages :: [sqs_batch_message, ...]) ::
          ExAws.Operation.Query.t()
  def send_message_batch(queue_url, messages) do
    params =
      messages
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {message, index}, params ->
        Map.merge(params, format_batch_message(message, index))
      end)

    request(queue_url, :send_message_batch, params)
  end

  @doc """
  Set attributes of a SQS Queue.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SetQueueAttributes.html)
  """
  @spec set_queue_attributes(queue_url :: binary, attributes :: queue_attributes) ::
          ExAws.Operation.Query.t()
  def set_queue_attributes(queue_url, attributes \\ []) do
    params =
      attributes
      |> build_attrs

    request(queue_url, :set_queue_attributes, params)
  end

  @doc """
  List tags of a SQS Queue.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ListQueueTags.html)
  """
  @spec list_queue_tags(queue_url :: binary) :: ExAws.Operation.Query.t()
  def list_queue_tags(queue_url) do
    request(queue_url, :list_queue_tags, %{})
  end

  @doc """
  Apply tags to a SQS Queue.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_TagQueue.html)
  """
  @spec tag_queue(queue_url :: binary, tags :: map) :: ExAws.Operation.Query.t()
  def tag_queue(queue_url, tags) do
    params = add_tags_to_params(tags)

    request(queue_url, :tag_queue, params)
  end

  @doc """
  Remove tags from a SQS Queue.

  [AWS API Docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_UntagQueue.html)
  """
  @spec untag_queue(queue_url :: binary, tag_keys :: list) :: ExAws.Operation.Query.t()
  def untag_queue(queue_url, tag_keys) do
    params = format_untag_list(tag_keys)
    request(queue_url, :untag_queue, params)
  end

  defp format_untag_list(tag_keys) do
    tag_keys
    |> Enum.with_index(1)
    |> Enum.reduce(%{}, fn {k, i}, acc -> Map.put(acc, "TagKey.#{i}", k) end)
  end

  defp add_tags_to_params(tags), do: add_tags_to_params(%{}, tags)

  defp add_tags_to_params(params, tags) do
    tags
    |> Enum.with_index(1)
    |> Enum.reduce(%{}, fn {{k, v}, i}, acc -> create_tag(acc, k, v, i) end)
    |> Map.merge(params)
  end

  defp create_tag(acc, key, value, index) do
    acc
    |> Map.put("Tag.#{index}.Key", key)
    |> Map.put("Tag.#{index}.Value", value)
  end

  defp request(nil, action, params) do
    generate_query(action, params)
  end

  defp request(queue_url, action, params) do
    query_params = params |> Map.put("QueueUrl", queue_url)
    generate_query(action, query_params)
  end

  defp generate_query(action, params) do
    action_string = action |> Atom.to_string() |> Macro.camelize()
    parser = fetch_parser!()

    %ExAws.Operation.Query{
      params: params |> Map.put("Action", action_string),
      service: :sqs,
      action: action,
      parser: &parser.parse/2
    }
  end

  defp fetch_parser!() do
    case Application.fetch_env(:ex_aws_sqs, :parser) do
      {:ok, parser} ->
        parser

      :error ->
        parser =
          cond do
            Code.ensure_loaded?(ExAws.SQS.SaxyParser) -> ExAws.SQS.SaxyParser
            Code.ensure_loaded?(ExAws.SQS.SweetXmlParser) -> ExAws.SQS.SweetXmlParser
            true -> raise "no XML parser found. Please add {:saxy, \"~> 1.1\"} to your mix.exs"
          end

        Application.put_env(:ex_aws_sqs, :parser, parser)
        parser
    end
  end

  ## Helpers

  defp format_permissions(%{} = permissions) do
    permissions
    |> expand_permissions
    |> Enum.with_index()
    |> Enum.map(&format_permission/1)
    |> Enum.reduce(%{}, &Map.merge(&1, &2))
  end

  defp expand_permissions(%{} = permissions) do
    Enum.reduce(permissions, [], fn permission, permissions ->
      [expand_permission(permission) | permissions]
    end)
    |> List.flatten()
  end

  defp expand_permission({account_id, :all}), do: {account_id, "*"}

  defp expand_permission({account_id, permissions}) do
    Enum.map(permissions, &{account_id, &1})
  end

  defp format_permission({{account_id, permission}, index}) do
    %{}
    |> Map.put("AWSAccountId.#{index + 1}", account_id)
    |> Map.put("ActionName.#{index + 1}", format_param_key(permission))
  end

  defp format_regular_opts(opts) do
    opts
    |> Enum.into(%{}, fn {k, v} ->
      {format_param_key(k), v}
    end)
  end

  defp format_param_key("*"), do: "*"
  # Key doesn't follow generic camelizing rule below.
  defp format_param_key(:aws_trace_header), do: "AWSTraceHeader"

  defp format_param_key(key) do
    key
    |> Atom.to_string()
    |> ExAws.Utils.camelize()
  end

  defp format_queue_attributes(:all), do: format_queue_attributes([:all])

  defp format_queue_attributes(attributes) do
    attributes
    |> Enum.with_index()
    |> Enum.map(&format_queue_attribute/1)
    |> Enum.reduce(%{}, &Map.merge(&1, &2))
  end

  defp format_queue_attribute({attribute, index}) do
    key = "AttributeName.#{index + 1}"

    Map.put(%{}, key, format_param_key(attribute))
  end

  defp format_message_attribute({attribute, index}) do
    %{"MessageAttributeName.#{index + 1}" => to_string(attribute)}
  end

  defp format_message_attributes(:all) do
    %{"MessageAttributeNames" => "All"}
  end

  defp format_message_attributes(attributes) do
    attributes
    |> Enum.with_index()
    |> Enum.map(&format_message_attribute/1)
    |> Enum.reduce(%{}, &Map.merge(&1, &2))
  end

  defp format_batch_message(message, index) do
    prefix = "SendMessageBatchRequestEntry.#{index + 1}."

    {attrs, opts} =
      message
      |> Keyword.pop(:message_attributes, [])

    attrs =
      attrs
      |> build_message_attrs

    opts
    |> format_regular_opts
    |> Map.merge(attrs)
    |> Enum.reduce(%{}, fn {key, value}, params ->
      Map.put(params, prefix <> key, value)
    end)
  end

  defp format_batch_deletion(message, index) do
    prefix = "DeleteMessageBatchRequestEntry.#{index + 1}."

    message
    |> format_regular_opts
    |> Enum.reduce(%{}, fn {key, value}, params ->
      Map.put(params, prefix <> key, value)
    end)
  end

  defp format_batch_visibility_change(message, index) do
    prefix = "ChangeMessageVisibilityBatchRequestEntry.#{index + 1}."

    message
    |> format_regular_opts
    |> Enum.reduce(%{}, fn {key, value}, params ->
      Map.put(params, prefix <> key, value)
    end)
  end

  defp build_attrs(attrs) do
    attrs
    |> Enum.with_index()
    |> Enum.map(&build_attr/1)
    |> Enum.reduce(%{}, &Map.merge(&1, &2))
  end

  defp build_attr({{name, value}, index}) do
    prefix = "Attribute.#{index + 1}."

    %{}
    |> Map.put(prefix <> "Name", format_param_key(name))
    |> Map.put(prefix <> "Value", value)
  end

  defp build_message_attrs(%{} = attr), do: build_message_attr({attr, 0})

  defp build_message_attrs(attrs) do
    attrs
    |> Enum.with_index()
    |> Enum.map(&build_message_attr/1)
    |> Enum.reduce(%{}, &Map.merge(&1, &2))
  end

  defp build_message_attr({attr, index}) do
    prefix = "MessageAttribute.#{index + 1}."

    %{}
    |> Map.put(prefix <> "Name", attr.name)
    |> Map.put(prefix <> "Value.DataType", message_data_type(attr))
    |> message_attr_value(prefix, attr)
  end

  defp message_data_type(%{data_type: data_type, custom_type: custom_type}) do
    format_param_key(data_type) <> "." <> custom_type
  end

  defp message_data_type(%{data_type: data_type}) do
    format_param_key(data_type)
  end

  defp message_attr_value(param, prefix, %{value: value, data_type: :binary}) do
    Map.put(param, prefix <> "Value.BinaryValue", value)
  end

  defp message_attr_value(param, prefix, %{value: value}) do
    Map.put(param, prefix <> "Value.StringValue", value)
  end
end
