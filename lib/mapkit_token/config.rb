require "pathname"

module MapkitToken
  class ConfigurationError < StandardError; end

  class Config
    ENV_NAMES = {
      :auth_key      => "MAPKIT_AUTH_KEY",
      :auth_key_path => "MAPKIT_AUTH_KEY_PATH",
      :auth_key_id   => "MAPKIT_AUTH_KEY_ID",
      :apple_team_id => "MAPKIT_APPLE_TEAM_ID"
    }.freeze

    PEM_MARKER = "-----BEGIN".freeze

    MISSING_AUTH_KEY = "No MapKit auth key. Carry the contents of the .p8 in " \
      "the credentials as `mapkit: auth_key` or in MAPKIT_AUTH_KEY, or name " \
      "the file with `mapkit: auth_key_path` or MAPKIT_AUTH_KEY_PATH.".freeze

    def auth_key
      carried = setting(:auth_key)
      return pem(carried) if carried.present?

      path = auth_key_path
      raise ConfigurationError, MISSING_AUTH_KEY if path.blank?

      file = expand_path(path)
      unless File.exist?(file)
        raise ConfigurationError, "MapKit auth key file not found at #{file}"
      end
      pem(File.read(file))
    end

    def auth_key_path
      setting(:auth_key_path)
    end

    def auth_key_id
      require_setting(:auth_key_id, "No MapKit key id. Set `mapkit: auth_key_id` or MAPKIT_AUTH_KEY_ID.")
    end

    def apple_team_id
      require_setting(:apple_team_id, "No Apple team id. Set `mapkit: apple_team_id` or MAPKIT_APPLE_TEAM_ID.")
    end

    def auth_key?
      auth_key
      true
    rescue ConfigurationError
      false
    end

    private

    def setting(name)
      from_initializer(name) || from_credentials(name) || from_env(name)
    end

    def require_setting(name, message)
      value = setting(name)
      raise ConfigurationError, message if value.blank?
      value
    end

    def from_initializer(name)
      MapkitToken.public_send(name).presence
    end

    def from_credentials(name)
      mapkit = credentials
      (mapkit[name] || mapkit[name.to_s]).presence
    end

    def from_env(name)
      ENV[ENV_NAMES.fetch(name)].presence
    end

    def credentials
      store = credentials_store
      return {} if store.nil?
      store.respond_to?(:to_h) ? store.to_h.symbolize_keys : {}
    rescue StandardError
      {}
    end

    def credentials_store
      app = application
      return nil if app.nil?

      if app.respond_to?(:credentials)
        app.credentials.mapkit
      elsif app.respond_to?(:secrets)
        app.secrets.mapkit
      end
    end

    def application
      return nil unless defined?(Rails) && Rails.respond_to?(:application)
      Rails.application
    end

    def app_root
      MapkitToken.app_root || (application && Rails.root) || Dir.pwd
    end

    def expand_path(path)
      pathname = Pathname.new(path.to_s)
      pathname.absolute? ? pathname.to_s : File.join(app_root.to_s, pathname.to_s)
    end

    def pem(value)
      key = value.to_s.strip.gsub('\n', "\n")
      return terminate(key) if key.include?(PEM_MARKER)

      decoded = begin
        key.unpack1("m").to_s.force_encoding(Encoding::UTF_8)
      rescue StandardError
        nil
      end
      decoded.to_s.include?(PEM_MARKER) ? terminate(decoded) : key
    end

    def terminate(key)
      key.end_with?("\n") ? key : key + "\n"
    end
  end
end
