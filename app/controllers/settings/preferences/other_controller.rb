# frozen_string_literal: true

class Settings::Preferences::OtherController < Settings::Preferences::BaseController
  include DtlHelper

  def show
    @dtl_enabled = DTL_ENABLED
    @dtl_tag = DTL_TAG
  end

  private

  def after_update_redirect_path
    settings_preferences_other_path
  end
end
