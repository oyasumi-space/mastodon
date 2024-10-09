# frozen_string_literal: true

module Admin
  class SensitiveWordsController < BaseController
    def show
      authorize :sensitive_words, :show?

      @admin_settings = Form::AdminSettings.new
      @sensitive_words = ::SensitiveWord.caches.presence || [::SensitiveWord.new]
    end

    def create
      authorize :sensitive_words, :create?

      begin
        ::SensitiveWord.save_from_raws(settings_params_test)
      rescue
        flash[:alert] = I18n.t('admin.ng_words.test_error')
        redirect_to after_update_redirect_path
        return
      end

      @admin_settings = Form::AdminSettings.new(settings_params)

      if @admin_settings.save
        flash[:notice] = I18n.t('generic.changes_saved_msg')
        redirect_to after_update_redirect_path
      else
        render :index
      end
    end

    private

    def after_update_redirect_path
      admin_sensitive_words_path
    end

    def settings_params
      params.require(:form_admin_settings).permit(*Form::AdminSettings::KEYS)
    end

    def settings_params_test
      params.require(:form_admin_settings)[:sensitive_words_test]
    end
  end
end
