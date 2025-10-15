# frozen_string_literal: true

module User::Confirmation
  extend ActiveSupport::Concern

  included do
    scope :confirmed, -> { where.not(confirmed_at: nil) }
    scope :unconfirmed, -> { where(confirmed_at: nil) }

    def confirm
      raise Mastodon::ValidationError, I18n.t('devise.registrations.sign_up_failed_because_reach_limit') if !invited? && reach_registrations_limit?

      wrap_email_confirmation { super }
    end
  end

  def confirmed?
    confirmed_at.present?
  end

  def unconfirmed?
    !confirmed?
  end
end
