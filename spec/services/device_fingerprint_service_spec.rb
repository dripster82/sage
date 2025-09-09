# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviceFingerprintService do
  let(:mock_request) { double('request') }

  before do
    allow(mock_request).to receive(:headers).and_return({
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      'Accept-Language' => 'en-US,en;q=0.9',
      'Accept-Encoding' => 'gzip, deflate, br',
      'X-Forwarded-For' => '192.168.1.100, 10.0.0.1',
      'DNT' => '1'
    })
    allow(mock_request).to receive(:remote_ip).and_return('192.168.1.100')
  end

  describe '.generate_from_request' do
    it 'generates a consistent fingerprint for the same request' do
      fingerprint1 = DeviceFingerprintService.generate_from_request(mock_request)
      fingerprint2 = DeviceFingerprintService.generate_from_request(mock_request)

      expect(fingerprint1).to eq(fingerprint2)
      expect(fingerprint1).to be_a(String)
      expect(fingerprint1.length).to eq(64) # SHA256 hex length
    end

    it 'generates different fingerprints for different requests' do
      # Create a second mock request with different headers
      mock_request2 = double('request')
      allow(mock_request2).to receive(:headers).and_return({
        'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15',
        'Accept-Language' => 'es-ES,es;q=0.9',
        'Accept-Encoding' => 'gzip, deflate',
        'X-Forwarded-For' => '10.0.0.50',
        'DNT' => '0'
      })
      allow(mock_request2).to receive(:remote_ip).and_return('10.0.0.50')

      fingerprint1 = DeviceFingerprintService.generate_from_request(mock_request)
      fingerprint2 = DeviceFingerprintService.generate_from_request(mock_request2)

      expect(fingerprint1).not_to eq(fingerprint2)
    end

    it 'handles missing headers gracefully' do
      minimal_request = double('request')
      allow(minimal_request).to receive(:headers).and_return({})
      allow(minimal_request).to receive(:remote_ip).and_return('127.0.0.1')

      expect {
        fingerprint = DeviceFingerprintService.generate_from_request(minimal_request)
        expect(fingerprint).to be_a(String)
        expect(fingerprint.length).to eq(64)
      }.not_to raise_error
    end

    it 'detects mobile devices correctly' do
      mobile_request = double('request')
      allow(mobile_request).to receive(:headers).and_return({
        'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Accept-Encoding' => 'gzip, deflate'
      })
      allow(mobile_request).to receive(:remote_ip).and_return('192.168.1.100')

      desktop_request = double('request')
      allow(desktop_request).to receive(:headers).and_return({
        'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Accept-Encoding' => 'gzip, deflate, br'
      })
      allow(desktop_request).to receive(:remote_ip).and_return('192.168.1.100')

      mobile_fingerprint = DeviceFingerprintService.generate_from_request(mobile_request)
      desktop_fingerprint = DeviceFingerprintService.generate_from_request(desktop_request)

      expect(mobile_fingerprint).not_to eq(desktop_fingerprint)
    end
  end

  describe 'private methods' do
    describe '.mobile_request?' do
      it 'detects mobile user agents' do
        mobile_agents = [
          'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)',
          'Mozilla/5.0 (Android 10; Mobile; rv:81.0)',
          'Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X)',
          'BlackBerry9700/5.0.0.862'
        ]

        mobile_agents.each do |agent|
          request = double('request')
          allow(request).to receive(:headers).and_return({ 'User-Agent' => agent })
          
          expect(DeviceFingerprintService.send(:mobile_request?, request)).to be true
        end
      end

      it 'does not detect desktop user agents as mobile' do
        desktop_agents = [
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
        ]

        desktop_agents.each do |agent|
          request = double('request')
          allow(request).to receive(:headers).and_return({ 'User-Agent' => agent })
          
          expect(DeviceFingerprintService.send(:mobile_request?, request)).to be false
        end
      end
    end
  end
end
