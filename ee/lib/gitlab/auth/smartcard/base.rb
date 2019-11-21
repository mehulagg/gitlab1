# frozen_string_literal: true

module Gitlab
  module Auth
    module Smartcard
      class Base
        InvalidCAFilePath = Class.new(StandardError)
        InvalidCertificate = Class.new(StandardError)

        delegate :allow_signup?,
                 to: :'Gitlab::CurrentSettings.current_application_settings'

        def self.store
          @store ||= OpenSSL::X509::Store.new.tap do |store|
            store.add_cert(
              OpenSSL::X509::Certificate.new(
                File.read(Gitlab.config.smartcard.ca_file)))
          end
        rescue Errno::ENOENT => ex
          logger.error(message: 'Failed to open Gitlab.config.smartcard.ca_file',
                       error: ex)

          raise InvalidCAFilePath
        rescue OpenSSL::X509::CertificateError => ex
          logger.error(message: 'Gitlab.config.smartcard.ca_file is not a valid certificate',
                       error: ex)

          raise InvalidCertificate
        end

        def self.logger
          @logger ||= ::Gitlab::AuthLogger.build
        end

        def initialize(certificate)
          @certificate = OpenSSL::X509::Certificate.new(certificate)
        rescue OpenSSL::X509::CertificateError
          # no-op, certificate verification fails in this case in #valid?
        end

        def find_or_create_user
          return unless valid?

          user = find_user
          user ||= create_identity_for_existing_user
          user ||= create_user if allow_signup?
          user
        end

        private

        def find_user
          raise NotImplementedError,
                "#{self.class.name} does not implement #{__method__}"
        end

        def create_identity_for_existing_user
          raise NotImplementedError,
                "#{self.class.name} does not implement #{__method__}"
        end

        def create_user
          raise NotImplementedError,
                "#{self.class.name} does not implement #{__method__}"
        end

        def valid?
          self.class.store.verify(@certificate) if @certificate
        end
      end
    end
  end
end
