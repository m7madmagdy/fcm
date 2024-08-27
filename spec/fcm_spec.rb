# frozen_string_literal: true

require 'spec_helper'

describe FCM do
  let(:send_url) { "#{FCM::BASE_URI}/fcm/send" }
  let(:group_notification_base_uri) { "#{FCM::GROUP_NOTIFICATION_BASE_URI}/gcm/notification" }
  let(:api_key) { 'AIzaSyB-1uEai2WiUapxCs2Q0GZYzPu7Udno5aA' }
  let(:registration_id) { '42' }
  let(:registration_ids) { ['42'] }
  let(:key_name) { 'appUser-Chris' }
  let(:project_id) { '123456789' }
  let(:notification_key) { 'APA91bGHXQBB...9QgnYOEURwm0I3lmyqzk2TXQ' }
  let(:valid_topic) { 'TopicA' }
  let(:invalid_topic) { 'TopicA$' }
  let(:valid_condition) { "'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)" }
  let(:invalid_condition) { "'TopicA' in topics and some other text ('TopicB' in topics || 'TopicC' in topics)" }
  let(:invalid_condition_topic) { "'TopicA$' in topics" }

  it 'should raise an error if the API key is not provided' do
    expect { FCM.new }.to raise_error(ArgumentError)
  end

  it 'should raise an error if `time_to_live` is given with invalid value' do
    # Add logic to raise error if time_to_live is invalid
    expect do
      FCM.new(api_key).send(registration_ids, time_to_live: -10)
    end.to raise_error(ArgumentError, 'Invalid `time_to_live` value.')
  end

  describe '#send_v1' do
    let(:project_name) { 'project_name' }
    let(:send_v1_url) { "#{FCM::BASE_URI_V1}#{project_name}/messages:send" }
    let(:access_token) { 'access_token' }
    let(:valid_request_v1_headers) do
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{access_token}"
      }
    end

    let(:send_v1_params) do
      {
        'token' => '4sdsx',
        'notification' => {
          'title' => 'Breaking News',
          'body' => 'New news story available.'
        },
        'data' => {
          'story_id' => 'story_12345'
        },
        'android' => {
          'notification' => {
            'click_action' => 'TOP_STORY_ACTIVITY',
            'body' => 'Check out the Top Story'
          }
        },
        'apns' => {
          'payload' => {
            'aps' => {
              'category' => 'NEW_MESSAGE_CATEGORY'
            }
          }
        }
      }
    end

    let(:valid_request_v1_body) do
      { 'message' => send_v1_params }
    end

    let(:stub_fcm_send_v1_request) do
      stub_request(:post, send_v1_url).with(
        body: valid_request_v1_body.to_json,
        headers: valid_request_v1_headers
      ).to_return(
        body: '{}',
        headers: {},
        status: 200
      )
    end

    let(:authorizer_double) { double('token_fetcher') }
    let(:json_key_path) { double('file alike object') }

    before do
      expect(json_key_path).to receive(:respond_to?).and_return(true)
      expect(Google::Auth::ServiceAccountCredentials).to receive_message_chain(:make_creds)
        .and_return(authorizer_double)
      expect(authorizer_double).to receive(:fetch_access_token!).and_return({ 'access_token' => access_token })
      stub_fcm_send_v1_request
    end

    it 'should send notification via HTTP V1 using POST to FCM server' do
      fcm = FCM.new(api_key, json_key_path, project_name)
      fcm.send_v1(send_v1_params).should eq(
        response: 'success', body: '{}', headers: {}, status_code: 200
      )
      stub_fcm_send_v1_request.should have_been_made.times(1)
    end
  end

  describe 'sending notification' do
    let(:valid_request_body) do
      { registration_ids: registration_ids }
    end
    let(:valid_request_body_with_string) do
      { registration_ids: registration_id }
    end
    let(:valid_request_headers) do
      {
        'Content-Type' => 'application/json',
        'Authorization' => "key=#{api_key}"
      }
    end

    let(:stub_fcm_send_request) do
      stub_request(:post, send_url).with(
        body: valid_request_body.to_json,
        headers: valid_request_headers
      ).to_return(
        body: '{}',
        headers: {},
        status: 200
      )
    end

    let(:stub_fcm_send_request_with_string) do
      stub_request(:post, send_url).with(
        body: valid_request_body_with_string.to_json,
        headers: valid_request_headers
      ).to_return(
        body: '{}',
        headers: {},
        status: 200
      )
    end

    let(:stub_fcm_send_request_with_basic_auth) do
      uri = URI.parse(send_url)
      uri.user = 'a'
      uri.password = 'b'
      stub_request(:post, uri.to_s).to_return(body: '{}', headers: {}, status: 200)
    end

    before(:each) do
      stub_fcm_send_request
      stub_fcm_send_request_with_string
      stub_fcm_send_request_with_basic_auth
    end

    it 'should send notification using POST to FCM server' do
      fcm = FCM.new(api_key)
      fcm.send(registration_ids).should eq(response: 'success', body: '{}', headers: {}, status_code: 200,
                                           canonical_ids: [], not_registered_ids: [])
      stub_fcm_send_request.should have_been_made.times(1)
    end

    it 'should send notification using POST to FCM if id provided as string' do
      fcm = FCM.new(api_key)
      fcm.send(registration_id).should eq(response: 'success', body: '{}', headers: {}, status_code: 200,
                                          canonical_ids: [], not_registered_ids: [])
      stub_fcm_send_request.should have_been_made.times(1)
    end

    context 'send notification with data' do
      let!(:stub_with_data) do
        stub_request(:post, send_url)
          .with(body: '{"registration_ids":["42"],"data":{"score":"5x1","time":"15:10"}}',
                headers: valid_request_headers)
          .to_return(status: 200, body: '', headers: {})
      end

      it 'should send the data in a POST request to FCM' do
        fcm = FCM.new(api_key)
        fcm.send(registration_ids, data: { score: '5x1', time: '15:10' })
        stub_with_data.should have_been_requested
      end
    end

    context 'sending notification to a topic' do
      let!(:stub_with_valid_topic) do
        stub_request(:post, send_url)
          .with(body: '{"to":"/topics/TopicA","data":{"score":"5x1","time":"15:10"}}',
                headers: valid_request_headers)
          .to_return(status: 200, body: '', headers: {})
      end
      let!(:stub_with_invalid_topic) do
        stub_request(:post, send_url)
          .with(body: '{"condition":"/topics/TopicA$","data":{"score":"5x1","time":"15:10"}}',
                headers: valid_request_headers)
          .to_return(status: 200, body: '', headers: {})
      end

      describe '#send_to_topic' do
        it 'should send the data in a POST request to FCM' do
          fcm = FCM.new(api_key)
          fcm.send_to_topic(valid_topic, data: { score: '5x1', time: '15:10' })
          stub_with_valid_topic.should have_been_requested
        end

        it 'should not send to invalid topics' do
          fcm = FCM.new(api_key)
          fcm.send_to_topic(invalid_topic, data: { score: '5x1', time: '15:10' })
          stub_with_invalid_topic.should_not have_been_requested
        end
      end
    end

    # rubocop:disable Layout/LineLength
    context 'sending notification to a topic condition' do
      let!(:stub_with_valid_condition) do
        stub_request(:post, send_url)
          .with(body: '{"condition":"\'TopicA\' in topics && (\'TopicB\' in topics || \'TopicC\' in topics)","data":{"score":"5x1","time":"15:10"}}',
                headers: valid_request_headers)
          .to_return(status: 200, body: '', headers: {})
      end
      let!(:stub_with_invalid_condition) do
        stub_request(:post, send_url)
          .with(body: '{"condition":"\'TopicA\' in topics and some other text (\'TopicB\' in topics || \'TopicC\' in topics)","data":{"score":"5x1","time":"15:10"}}',
                headers: valid_request_headers)
          .to_return(status: 200, body: '', headers: {})
      end

      let!(:stub_with_invalid_condition_topic) do
        stub_request(:post, send_url)
          .with(body: '{"condition":"\'TopicA$\' in topics","data":{"score":"5x1","time":"15:10"}}',
                headers: valid_request_headers)
          .to_return(status: 200, body: '', headers: {})
      end

      describe '#send_with_notification_key_and_condition' do
        it 'should send to a valid condition' do
          fcm = FCM.new(api_key)
          fcm.send_with_notification_key_and_condition(valid_condition, data: { score: '5x1', time: '15:10' })
          stub_with_valid_condition.should have_been_requested
        end

        it 'should not send to invalid condition' do
          fcm = FCM.new(api_key)
          fcm.send_with_notification_key_and_condition(invalid_condition, data: { score: '5x1', time: '15:10' })
          stub_with_invalid_condition.should_not have_been_requested
        end

        it 'should not send to invalid condition topics' do
          fcm = FCM.new(api_key)
          fcm.send_with_notification_key_and_condition(invalid_condition_topic, data: { score: '5x1', time: '15:10' })
          stub_with_invalid_condition_topic.should_not have_been_requested
        end
      end
    end
    # rubocop:enable Layout/LineLength

    it 'should return 401 when FCM responds with a 401' do
      stub_request(:post, send_url).with(
        body: valid_request_body.to_json,
        headers: valid_request_headers
      ).to_return(
        body: '{}',
        headers: {},
        status: 401
      )

      fcm = FCM.new(api_key)
      response = fcm.send(registration_ids)
      expect(response[:status_code]).to eq(401)
    end

    context 'sending notification to multiple devices' do
      let(:registration_ids) { %w[42 43 44] }
      let(:valid_request_body_multiple_devices) do
        { registration_ids: registration_ids }
      end

      let(:valid_request_headers) do
        {
          'Content-Type' => 'application/json',
          'Authorization' => "key=#{api_key}"
        }
      end

      let(:stub_fcm_send_request_multiple_devices) do
        stub_request(:post, send_url).with(
          body: valid_request_body_multiple_devices.to_json,
          headers: valid_request_headers
        ).to_return(
          body: '{}',
          headers: {},
          status: 200
        )
      end

      before(:each) do
        stub_fcm_send_request_multiple_devices
      end

      it 'should send notification to multiple devices using POST to FCM server' do
        fcm = FCM.new(api_key)
        fcm.send(registration_ids).should eq(response: 'success', body: '{}', headers: {}, status_code: 200,
                                             canonical_ids: [], not_registered_ids: [])
        stub_fcm_send_request_multiple_devices.should have_been_made.times(1)
      end
    end
  end
end
