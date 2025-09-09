# frozen_string_literal: true

class DeviceFingerprintService
  def self.generate_from_request(request)
    components = [
      extract_user_agent(request),
      extract_accept_language(request),
      extract_accept_encoding(request),
      extract_client_ip(request),
      extract_x_forwarded_for(request),
      extract_connection_info(request)
    ].compact
    
    # Create a hash from the combined components
    Digest::SHA256.hexdigest(components.join('|'))
  end

  private

  def self.extract_user_agent(request)
    request.headers['User-Agent']&.strip
  end

  def self.extract_accept_language(request)
    # Extract and normalize Accept-Language header
    lang = request.headers['Accept-Language']
    return nil unless lang
    
    # Take only the primary languages, ignore quality values
    lang.split(',').map { |l| l.split(';').first&.strip }.compact.sort.join(',')
  end

  def self.extract_accept_encoding(request)
    # Extract Accept-Encoding header
    encoding = request.headers['Accept-Encoding']
    return nil unless encoding
    
    # Normalize encoding preferences
    encoding.split(',').map(&:strip).sort.join(',')
  end

  def self.extract_client_ip(request)
    # Get the most reliable client IP
    request.remote_ip
  end

  def self.extract_x_forwarded_for(request)
    # Extract X-Forwarded-For if present (useful for proxy detection)
    xff = request.headers['X-Forwarded-For']
    return nil unless xff
    
    # Take the first IP in the chain (original client)
    xff.split(',').first&.strip
  end

  def self.extract_connection_info(request)
    # Extract connection-related headers that might indicate device type
    components = []
    
    # Check for mobile indicators
    components << 'mobile' if mobile_request?(request)
    
    # Check for common client hints if available
    components << request.headers['Sec-CH-UA-Platform'] if request.headers['Sec-CH-UA-Platform']
    components << request.headers['Sec-CH-UA-Mobile'] if request.headers['Sec-CH-UA-Mobile']
    
    # Check for DNT (Do Not Track) header
    components << "dnt:#{request.headers['DNT']}" if request.headers['DNT']
    
    components.empty? ? nil : components.join(',')
  end

  def self.mobile_request?(request)
    user_agent = request.headers['User-Agent']
    return false unless user_agent
    
    mobile_patterns = [
      /Mobile/i, /Android/i, /iPhone/i, /iPad/i, /iPod/i,
      /BlackBerry/i, /Windows Phone/i, /Opera Mini/i
    ]
    
    mobile_patterns.any? { |pattern| user_agent.match?(pattern) }
  end
end
