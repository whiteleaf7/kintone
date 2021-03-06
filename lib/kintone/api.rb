require 'faraday'
require 'faraday_middleware'
require 'base64'
require 'json'
require 'kintone/command/accessor'
require 'kintone/api/guest'
require 'kintone/query'
require 'kintone/kintone_error'

class Kintone::Api
  BASE_PATH = '/k/v1/'.freeze
  COMMAND = '%s.json'.freeze
  ACCESSIBLE_COMMAND = [
    :record, :records, :form, :app_acl, :record_acl,
    :field_acl, :template_space, :space, :space_body, :space_thread,
    :space_members, :guests, :app, :apps, :apis,
    :bulk_request, :bulk, :file
  ].freeze

  def initialize(domain, user, password = nil, basic_user=nil, basic_password=nil)

    token = Base64.encode64("#{user}:#{password}")
    url = "https://#{domain}"
    headers = { 'X-Cybozu-Authorization' => token }

    if basic_user.present? && basic_password.present?
      #basic_token = Base64.encode64("#{basic_user}:#{basic_password}")
      #headers['Authorization'] = "Basic: #{basic_token}"
      url = "https://#{basic_user}:#{basic_password}@#{domain}"
    end

    #domain2 = "https://#{basic_user}:#{basic_password}@#{ENV['KINTONE_HOST']}"
    #domain2 = "https://#{ENV['KINTONE_HOST']}:443"
    #res = `curl -X GET "#{domain2}/k/v1/apps.json" \
    #-H "Authorization: #{headers['Authorization']}" \
    #-H "X-Cybozu-Authorization: #{headers['X-Cybozu-Authorization']}"`

    #raise res.inspect

    @connection =
      Faraday.new(url: "https://#{domain}", headers: build_headers(user, password)) do |builder|
        builder.request :url_encoded
        builder.request :multipart
        builder.response :json, content_type: /\bjson$/
        builder.adapter :net_http
      end
  end

  def get_url(command)
    BASE_PATH + (COMMAND % command)
  end

  def guest(space_id)
    Kintone::Api::Guest.new(space_id, self)
  end

  def get(url, params = {})
    response =
      @connection.get do |request|
        request.url url
        request.params = params
      end
    raise Kintone::KintoneError.new(response.body, response.status) if response.status != 200
    response.body
  end

  def post(url, body)
    response =
      @connection.post do |request|
        request.url url
        request.headers['Content-Type'] = 'application/json'
        request.body = body.to_json
      end
    raise Kintone::KintoneError.new(response.body, response.status) if response.status != 200
    response.body
  end

  def put(url, body)
    response =
      @connection.put do |request|
        request.url url
        request.headers['Content-Type'] = 'application/json'
        request.body = body.to_json
      end
    raise Kintone::KintoneError.new(response.body, response.status) if response.status != 200
    response.body
  end

  def delete(url, body = nil)
    response =
      @connection.delete do |request|
        request.url url
        request.headers['Content-Type'] = 'application/json'
        request.body = body.to_json
      end
    raise Kintone::KintoneError.new(response.body, response.status) if response.status != 200
    response.body
  end

  def post_file(url, path, content_type, original_filename)
    response =
      @connection.post do |request|
        request.url url
        request.headers['Content-Type'] = 'multipart/form-data'
        request.body = { file: Faraday::UploadIO.new(path, content_type, original_filename) }
      end
    raise Kintone::KintoneError.new(response.body, response.status) if response.status != 200
    response.body['fileKey']
  end

  def method_missing(name, *args)
    if ACCESSIBLE_COMMAND.include?(name)
      CommandAccessor.send(name, self)
    else
      super
    end
  end

  def respond_to_missing?(name, *args)
    ACCESSIBLE_COMMAND.include?(name) || super
  end

  class CommandAccessor
    extend Kintone::Command::Accessor
  end

  private

  def build_headers(user, password)
    if password # パスワード認証
      { 'X-Cybozu-Authorization' => Base64.encode64("#{user}:#{password}") }
    else # APIトークン認証
      { 'X-Cybozu-API-Token' => user }
    end
  end
end
