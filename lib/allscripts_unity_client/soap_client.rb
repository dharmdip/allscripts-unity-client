module AllscriptsUnityClient
  class SOAPClient < BaseClient
    UNITY_SOAP_ENDPOINT = "/Unity/UnityService.svc/unityservice"
    UNITY_ENDPOINT_NAMESPACE = "http://www.allscripts.com/Unity/IUnityService"

    def setup!
      client_proxy = @proxy
      base_unity_url = "#{@base_unity_url}#{UNITY_SOAP_ENDPOINT}"

      @savon_client = Savon.client do
        # Removes the wsdl: namespace from body elements in the SOAP
        # request. Unity doesn't recognize elements otherwise.
        namespace_identifier nil

        # Manually registers SOAP endpoint since Unity WSDL is not very
        # good.
        endpoint base_unity_url

        # Manually register SOAP namespace. This URL isn't live, but the
        # internal SOAP endpoints expect it.
        namespace "http://www.allscripts.com/Unity"

        # Register proxy with Savon if one was given.
        unless client_proxy.nil?
          proxy client_proxy
        end

        # Unity expects the SOAP envelop to be namespaced with soap:
        env_namespace :soap

        # Unity uses Microsoft style CamelCase for keys. Only really useful when using
        # symbol keyed hashes.
        convert_request_keys_to :camelcase

        # Enable gzip on HTTP responses
        headers({ "Accept-Encoding" => "gzip, deflate" })
      end

      get_security_token!
    end

    def magic(parameters = {})
      call_data = {
        :message => map_magic_request(parameters),
        :soap_action => "#{UNITY_ENDPOINT_NAMESPACE}/Magic"
      }

      begin
        response = @savon_client.call("Magic", call_data)
      rescue Savon::SOAPFault => e
        raise APIError, e.message
      end

      map_magic_response(response.body, parameters[:action])
    end

    def get_security_token!(parameters = {})
      username = parameters[:username] || @username
      password = parameters[:password] || @password
      appname = parameters[:appname] || @appname

      call_data = {
        :message => {
          "Username" => username,
          "Password" => password,
          "Appname" => appname
        },
        :soap_action => "#{UNITY_ENDPOINT_NAMESPACE}/GetSecurityToken"
      }

      begin
        response = @savon_client.call("GetSecurityToken", call_data)
      rescue Savon::SOAPFault => e
        raise APIError, e.message
      end

      @security_token = response.body[:get_security_token_response][:get_security_token_result]
    end

    def retire_security_token!(parameters = {})
      token = parameters[:token] || @security_token
      appname = parameters[:appname] || @appname

      call_data = {
        :message => {
          "Token" => token,
          "Appname" => appname
        },
        :soap_action => "#{UNITY_ENDPOINT_NAMESPACE}/RetireSecurityToken"
      }

      begin
        @savon_client.call("RetireSecurityToken", call_data)
      rescue Savon::SOAPFault => e
        raise APIError, e.message
      end

      @security_token = nil
    end
  end
end