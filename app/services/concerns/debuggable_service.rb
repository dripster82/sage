
module DebuggableService
  extend ActiveSupport::Concern

  included do
    def debug_log(message)
      return unless Rails.env.development?
      Rails.logger.debug(message)
    end
  end
end
