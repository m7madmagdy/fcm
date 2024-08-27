# Firebase Cloud Messaging (FCM) for Android and iOS

[![Gem Version](https://badge.fury.io/rb/fcm.svg)](http://badge.fury.io/rb/fcm) [![Build Status](https://github.com/decision-labs/fcm/workflows/Tests/badge.svg)](https://github.com/decision-labs/fcm/actions)

The FCM gem lets your ruby backend send notifications to Android and iOS devices via [
Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging/).

## Installation

```sh
gem install fcm
```

or in your `Gemfile` just include it:

```ruby
gem 'fcm'
```

## Requirements

For Android you will need a device running 2.3 (or newer) that also have the Google Play Store app installed, or an emulator running Android 2.3 with Google APIs. iOS devices are also supported.

A version of supported Ruby, currently:
`ruby >= 2.4`

## Getting Started

To use this gem, you need to instantiate a client with your firebase credentials:

```ruby
fcm = FCM.new(
  nil,
  GOOGLE_APPLICATION_CREDENTIALS_PATH,
  FIREBASE_PROJECT_ID
)
```

## About the `GOOGLE_APPLICATION_CREDENTIALS_PATH`

The `GOOGLE_APPLICATION_CREDENTIALS_PATH` is meant to contain your firebase credentials. See the [Firebase V1 Migration docs](https://firebase.google.com/docs/cloud-messaging/migrate-v1#provide-credentials-manually) for instructions to create a private key file.

The easiest way to provide them is to pass here an absolute path to a file with your credentials:

```ruby
fcm = FCM.new(
  nil,
  '/path/to/credentials.json',
  FIREBASE_PROJECT_ID
)
```

As per their secret nature, you might not want to have them in your repository. In that case, another supported solution is to pass a `StringIO` that contains your credentials:

```ruby
fcm = FCM.new(
  nil,
  StringIO.new(ENV.fetch('FIREBASE_CREDENTIALS')),
  FIREBASE_PROJECT_ID
)

```

## Usage

## HTTP v1 API

To migrate to HTTP v1 see: https://firebase.google.com/docs/cloud-messaging/migrate-v1

```ruby
fcm = FCM.new(
  nil,
  GOOGLE_APPLICATION_CREDENTIALS_PATH,
  FIREBASE_PROJECT_ID
)
message = {
  'topic': "89023", # OR token if you want to send to a specific device
  # 'token': "000iddqd",
  'data': {
    payload: {
      data: {
        id: 1
      }
    }.to_json
  },
  'notification': {
    title: notification.title_th,
    body: notification.body_th,
  },
  'android': {},
  'apns': {
    payload: {
      aps: {
        sound: "default",
        category: "#{Time.zone.now.to_i}"
      }
    }
  },
  'fcm_options': {
    analytics_label: 'Label'
  }
}

fcm.send_v1(message)
```
## Send Messages to Topics

FCM [topic messaging](https://firebase.google.com/docs/cloud-messaging/topic-messaging) allows your app server to send a message to multiple devices that have opted in to a particular topic. Based on the publish/subscribe model, topic messaging supports unlimited subscriptions per app. Sending to a topic is very similar to sending to an individual device or to a user group, in the sense that you can use the `fcm.send_with_notification_key()` method where the `notification_key` matches the regular expression `"/topics/[a-zA-Z0-9-_.~%]+"`:

```ruby
response = fcm.send_with_notification_key("/topics/yourTopic",
            notification: {body: "This is a FCM Topic Message!"})
```

Or you can use the helper:

```ruby
response = fcm.send_to_topic("yourTopic",
            notification: {body: "This is a FCM Topic Message!"})
```

### Sending to Multiple Topics

To send to combinations of multiple topics, the FCM [docs](https://firebase.google.com/docs/cloud-messaging/send-message#send_messages_to_topics_2) require that you set a **condition** key (instead of the `to:` key) to a boolean condition that specifies the target topics. For example, to send messages to devices that subscribed to _TopicA_ and either _TopicB_ or _TopicC_:

```
'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)
```

FCM first evaluates any conditions in parentheses, and then evaluates the expression from left to right. In the above expression, a user subscribed to any single topic does not receive the message. Likewise, a user who does not subscribe to TopicA does not receive the message. These combinations do receive it:

- TopicA and TopicB
- TopicA and TopicC

You can include up to five topics in your conditional expression, and parentheses are supported. Supported operators: `&&`, `||`, `!`. Note the usage for !:

```
!('TopicA' in topics)
```

With this expression, any app instances that are not subscribed to TopicA, including app instances that are not subscribed to any topic, receive the message.

The `send_to_topic_condition` method within this library allows you to specicy a condition of multiple topics to which to send to the data payload.

```ruby
response = fcm.send_to_topic_condition(
  "'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)",
  notification: {
    body: "This is an FCM Topic Message sent to a condition!"
  }
)
```

## Subscribe the client app to a topic

Given a registration token and a topic name, you can add the token to the topic using the [Google Instance ID server API](https://developers.google.com/instance-id/reference/server).

```ruby
topic = "YourTopic"
registration_id= "12" # a client registration tokens
response = fcm.topic_subscription(topic, registration_id)
```

Or you can manage relationship maps for multiple app instances [Google Instance ID server API. Manage relationship](https://developers.google.com/instance-id/reference/server#manage_relationship_maps_for_multiple_app_instances)

```ruby
topic = "YourTopic"
registration_ids= ["4", "8", "15", "16", "23", "42"] # an array of one or more client registration tokens
response = fcm.batch_topic_subscription(topic, registration_ids)
# or unsubscription
response = fcm.batch_topic_unsubscription(topic, registration_ids)
```

## Mobile Clients

You can find a guide to implement an Android Client app to receive notifications here: [Set up a FCM Client App on Android](https://firebase.google.com/docs/cloud-messaging/android/client).

The guide to set up an iOS app to get notifications is here: [Setting up a FCM Client App on iOS](https://firebase.google.com/docs/cloud-messaging/ios/client).

## ChangeLog

### 1.0.8

- caches calls to `Google::Auth::ServiceAccountCredentials` #103
- Allow `faraday` versions from 1 up to 2  #101

### 1.0.7

- Fix passing `DEFAULT_TIMEOUT` to `faraday` [#96](https://github.com/decision-labs/fcm/pull/96)
- Fix issue with `get_instance_id_info` option params [#98](https://github.com/decision-labs/fcm/pull/98)
- Accept any IO object for credentials [#95](https://github.com/decision-labs/fcm/pull/94)

Huge thanks to @excid3 @jsparling @jensljungblad

### 1.0.3

- Fix overly strict faraday dependency

### 1.0.2

- Bug fix: retrieve notification key" params: https://github.com/spacialdb/fcm/commit/b328a75c11d779a06d0ceda83527e26aa0495774

### 1.0.0

- Bumped supported ruby to `>= 2.4`
- Fix deprecation warnings from `faraday` by changing dependency version to `faraday 1.0.0`

### 0.0.7

- replace `httparty` with `faraday`

### 0.0.2

- Fixed group messaging url.
- Added API to `recover_notification_key`.

### 0.0.1

- Initial version.

## MIT License

- Copyright (c) 2016 Kashif Rasul and Shoaib Burq. See LICENSE.txt for details.

## Many thanks to all the contributors

- [Contributors](https://github.com/spacialdb/fcm/contributors)

## Cutting a release

Update version in `fcm.gemspec` with `VERSION` and update `README.md` `## ChangeLog` section.

```bash
# set the version
# VERSION="1.0.7"
gem build fcm.gemspec
git tag -a v${VERSION} -m "Releasing version v${VERSION}"
git push origin --tags
gem push fcm-${VERSION}.gem
```
