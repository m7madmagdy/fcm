require 'faraday'
require 'cgi'
require 'json'
require 'googleauth'

class FCM
  BASE_URI = 'https://fcm.googleapis.com'.freeze
  BASE_URI_V1 = 'https://fcm.googleapis.com/v1/projects/'.freeze
  DEFAULT_TIMEOUT = 30

  def initialize(json_key_path = '', project_name = '')
    @json_key_path = json_key_path
    @project_name = project_name
  end

  def send_notification_v1(message)
    return if @project_name.empty?

    post_body = { message: message }
    extra_headers = {
      'Authorization' => "Bearer #{jwt_token}"
    }
    for_uri(BASE_URI_V1, extra_headers) do |connection|
      response = connection.post(
        "#{@project_name}/messages:send", post_body.to_json
      )
      build_response(response)
    end
  end

  alias send_v1 send_notification_v1

  def send_to_topic_condition(condition, options = {})
    return unless validate_condition?(condition)

    message = { condition: condition }.merge(options)
    post_body = { message: message }

    extra_headers = {
      'Authorization' => "Bearer #{jwt_token}"
    }

    for_uri(BASE_URI_V1, extra_headers) do |connection|
      response = connection.post(
        "#{@project_name}/messages:send", post_body.to_json
      )
      build_response(response)
    end
  end

  private

  def for_uri(uri, extra_headers = {})
    connection = ::Faraday.new(
      url: uri,
      request: { timeout: DEFAULT_TIMEOUT }
    ) do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-Type'] = 'application/json'
      faraday.headers['Authorization'] = "key=#{@api_key}"
      extra_headers.each do |key, value|
        faraday.headers[key] = value
      end
    end
    yield connection
  end

  def build_post_body(registration_ids, options = {})
    ids = registration_ids.is_a?(String) ? [registration_ids] : registration_ids
    { registration_ids: ids }.merge(options)
  end

  def build_response(response, registration_ids = [])
    body = response.body || {}
    response_hash = { body: body, headers: response.headers, status_code: response.status }
    case response.status
    when 200
      response_hash[:response] = 'success'
      body = JSON.parse(body) unless body.empty?
      response_hash[:canonical_ids] = build_canonical_ids(body, registration_ids) unless registration_ids.empty?
      unless registration_ids.empty?
        response_hash[:not_registered_ids] =
          build_not_registered_ids(body, registration_ids)
      end
    when 400
      response_hash[:response] =
        'Only applies for JSON requests. Indicates that the request could not be parsed as JSON, or it contained invalid fields.'
    when 401
      response_hash[:response] = 'There was an error authenticating the sender account.'
    when 503
      response_hash[:response] = 'Server is temporarily unavailable.'
    when 500..599
      response_hash[:response] = 'There was an internal error in the FCM server while trying to process the request.'
    end
    response_hash
  end

  def build_canonical_ids(body, registration_ids)
    canonical_ids = []
    if !body.empty? && body['canonical_ids'] > (0)
      body['results'].each_with_index do |result, index|
        canonical_ids << { old: registration_ids[index], new: result['registration_id'] } if canonical_id?(result)
      end
    end
    canonical_ids
  end

  def build_not_registered_ids(body, registration_id)
    not_registered_ids = []
    if !body.empty? && body['failure'] > (0)
      body['results'].each_with_index do |result, index|
        not_registered_ids << registration_id[index] if not_registered?(result)
      end
    end
    not_registered_ids
  end

  def execute_notification(body)
    for_uri(BASE_URI) do |connection|
      response = connection.post('/fcm/send', body.to_json)
      build_response(response)
    end
  end

  def canonical_id?(result)
    !result['registration_id'].nil?
  end

  def not_registered?(result)
    result['error'] == 'NotRegistered'
  end

  def validate_condition?(condition)
    validate_condition_format?(condition) && validate_condition_topics?(condition)
  end

  def validate_condition_format?(condition)
    bad_characters = condition.gsub(
      /(topics|in|\s|\(|\)|(&&)|[!]|(\|\|)|'([a-zA-Z0-9\-_.~%]+)')/,
      ''
    )
    bad_characters.length.empty?
  end

  def validate_condition_topics?(condition)
    topics = condition.scan(/(?:^|\S|\s)'([^']*?)'(?:$|\S|\s)/).flatten
    topics.all? { |topic| topic.gsub(TOPIC_REGEX, '').length.empty? }
  end

  def jwt_token
    scope = 'https://www.googleapis.com/auth/firebase.messaging'
    @authorizer ||= Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: json_key,
      scope: scope
    )
    token = @authorizer.fetch_access_token!
    token['access_token']
  end

  def json_key
    @json_key ||= if @json_key_path.respond_to?(:read)
                    @json_key_path
                  else
                    File.open(@json_key_path)
                  end
  end
end
