# frozen_string_literal: true

module ActiveResource
  class ConnectionError < StandardError # :nodoc:
    attr_reader :request, :response

    def initialize(request, response = nil, message = nil)
      if request.is_a?(Net::HTTPResponse) && (response.is_a?(String) || response.nil?)
        ActiveResource.deprecator.warn(<<~WARN)
          ConnectionError subclasses must be constructed with a request. Call super with a Net::HTTPRequest instance as the first argument.
        WARN

        message = response
        response, request = request, nil
      end

      @request  = request
      @response = response
      @message  = message
    end

    def to_s
      return @message if @message

      message = +"Failed."
      message << "  Request = #{request.method} #{request.uri}." if request.respond_to?(:method) && request.respond_to?(:uri)
      message << "  Response code = #{response.code}." if response.respond_to?(:code)
      message << "  Response message = #{response.message}." if response.respond_to?(:message)
      message
    end
  end

  # Raised when a Timeout::Error occurs.
  class TimeoutError < ConnectionError
    def initialize(request, message = nil)
      if request.is_a?(String)
        ActiveResource.deprecator.warn(<<~WARN)
          TimeoutError subclasses must be constructed with a request. Call super with a Net::HTTPRequest instance as the first argument.
        WARN

        message, request = request, nil
      end

      @request = request
      @message = message
    end
    def to_s; @message ; end
  end

  # Raised when a OpenSSL::SSL::SSLError occurs.
  class SSLError < ConnectionError
    def initialize(request, message = nil)
      if request.is_a?(String)
        ActiveResource.deprecator.warn(<<~WARN)
          SSLError subclasses must be constructed with a request. Call super with a Net::HTTPRequest instance as the first argument.
        WARN

        message, request = request, nil
      end

      @request = request
      @message = message
    end
    def to_s; @message ; end
  end

  # Raised when a Errno::ECONNREFUSED occurs.
  class ConnectionRefusedError < Errno::ECONNREFUSED
    attr_reader :request

    def initialize(request, message)
      @request = request
      super(message)
    end
  end

  # 3xx Redirection
  class Redirection < ConnectionError # :nodoc:
    def to_s
      response["Location"] ? "#{super} => #{response['Location']}" : super
    end
  end

  class MissingPrefixParam < ArgumentError # :nodoc:
  end

  # 4xx Client Error
  class ClientError < ConnectionError # :nodoc:
  end

  # 400 Bad Request
  class BadRequest < ClientError # :nodoc:
  end

  # 401 Unauthorized
  class UnauthorizedAccess < ClientError # :nodoc:
  end

  # 402 Payment Required
  class PaymentRequired < ClientError # :nodoc:
  end

  # 403 Forbidden
  class ForbiddenAccess < ClientError # :nodoc:
  end

  # 404 Not Found
  class ResourceNotFound < ClientError # :nodoc:
  end

  # 409 Conflict
  class ResourceConflict < ClientError # :nodoc:
  end

  # 410 Gone
  class ResourceGone < ClientError # :nodoc:
  end

  # 412 Precondition Failed
  class PreconditionFailed < ClientError # :nodoc:
  end

  # 429 Too Many Requests
  class TooManyRequests < ClientError # :nodoc:
  end

  # 451 Unavailable For Legal Reasons
  class UnavailableForLegalReasons < ClientError # :nodoc:
  end

  # 5xx Server Error
  class ServerError < ConnectionError # :nodoc:
  end

  # 405 Method Not Allowed
  class MethodNotAllowed < ClientError # :nodoc:
    def allowed_methods
      @response["Allow"].split(",").map { |verb| verb.strip.downcase.to_sym }
    end
  end
end
