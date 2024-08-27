require "faraday"
require "cgi"
require "json"
require "googleauth"

class FCM
  BASE_URI_V1 = "https://fcm.googleapis.com/v1/projects/"
  TOPIC_REGEX = /[a-zA-Z0-9\-_.~%]+/
  DEFAULT_TIMEOUT = 30

  def initialize(json_key_path, project_name)
    @json_key_path = json_key_path
    @project_name = project_name
  end

  def send_notification_v1(message)
    return if @project_name.empty?

    post_body = { 'message': message }
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

  def send_to_topic(topic, options = {})
    message = {
      topic: topic
    }.merge(options)
    send_notification_v1(message)
  end

  def send_to_condition(condition, options = {})
    return unless validate_condition?(condition)

    message = {
      condition: condition
    }.merge(options)
    send_notification_v1(message)
  end

  def send_to_token(token, options = {})
    message = {
      token: token
    }.merge(options)
    send_notification_v1(message)
  end

  def send_to_multiple_devices(registration_tokens, options = {})
    return if @project_name.empty? || registration_tokens.empty?

    message = {
      tokens: registration_tokens,
      options
    }

    post_body = { 'message': message }
    extra_headers = {
      'Authorization' => "Bearer #{jwt_token}"
    }
    for_uri(BASE_URI_V1, extra_headers) do |connection|
      response = connection.post(
        "#{@project_name}/messages:send", post_body.to_json
      )
      build_response(response, registration_tokens)
    end
  end

  private

  def for_uri(uri, extra_headers = {})
    connection = ::Faraday.new(
      url: uri,
      request: { timeout: DEFAULT_TIMEOUT }
    ) do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.headers["Content-Type"] = "application/json"
      extra_headers.each do |key, value|
        faraday.headers[key] = value
      end
    end
    yield connection
  end

  def build_response(response)
    body = response.body || {}
    response_hash = { body: body, headers: response.headers, status_code: response.status }

    case response.status
    when 200
      response_hash[:response] = "success"
      response_hash[:parsed_body] = JSON.parse(body) unless body.empty?
    when 400
      response_hash[:response] = "Invalid JSON or request fields."
    when 401
      response_hash[:response] = "Authentication error."
    when 503
      response_hash[:response] = "Server temporarily unavailable."
    when 500..599
      response_hash[:response] = "Internal FCM server error."
    end
    response_hash
  end

  def validate_condition?(condition)
    validate_condition_format?(condition) && validate_condition_topics?(condition)
  end

  def validate_condition_format?(condition)
    bad_characters = condition.gsub(
      /(topics|in|\s|\(|\)|(&&)|[!]|(\|\|)|'([a-zA-Z0-9\-_.~%]+)')/,
      ""
    )
    bad_characters.empty?
  end

  def validate_condition_topics?(condition)
    topics = condition.scan(/(?:^|\S|\s)'([^']*?)'(?:$|\S|\s)/).flatten
    topics.all? { |topic| topic.match(TOPIC_REGEX) }
  end

  def jwt_token
    scope = "https://www.googleapis.com/auth/firebase.messaging"
    @authorizer ||= Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: json_key,
      scope: scope,
    )
    token = @authorizer.fetch_access_token!
    token["access_token"]
  end

  def json_key
    @json_key ||= if @json_key_path.respond_to?(:read)
                    @json_key_path
                  else
                    File.open(@json_key_path)
                  end
  end
end
