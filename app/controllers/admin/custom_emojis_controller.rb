# frozen_string_literal: true

module Admin
  class CustomEmojisController < BaseController
    before_action :set_custom_emoji, only: [:edit, :update]

    def index
      authorize :custom_emoji, :index?

      @custom_emojis = filtered_custom_emojis.eager_load(:local_counterpart).page(params[:page]).without_count
      @form          = Form::CustomEmojiBatch.new
    end

    def new
      authorize :custom_emoji, :create?

      @custom_emoji = CustomEmoji.new
    end

    def edit
      authorize :custom_emoji, :create?
    end

    def create
      authorize :custom_emoji, :create?

      @custom_emoji = CustomEmoji.new(resource_params)

      if @custom_emoji.save
        log_action :create, @custom_emoji
        redirect_to admin_custom_emojis_path, notice: I18n.t('admin.custom_emojis.created_msg')
      else
        render :new
      end
    end

    def update
      authorize :custom_emoji, :create?

      @custom_emoji.assign_attributes(update_params)

      if @custom_emoji.save
        log_action :update, @custom_emoji
        redirect_to admin_custom_emojis_path(filter_params), notice: I18n.t('admin.custom_emojis.updated_msg')
      else
        render :new
      end
    end

    def batch
      authorize :custom_emoji, :index?

      @form = Form::CustomEmojiBatch.new(form_custom_emoji_batch_params.merge(current_account: current_account, action: action_from_button))
      @form.save
    rescue ActionController::ParameterMissing
      flash[:alert] = I18n.t('admin.custom_emojis.no_emoji_selected')
    rescue Mastodon::NotPermittedError
      flash[:alert] = I18n.t('admin.custom_emojis.not_permitted')
    ensure
      redirect_to admin_custom_emojis_path(filter_params)
    end

    private

    def set_custom_emoji
      @custom_emoji = CustomEmoji.find(params[:id])
    end

    def resource_params
      params.require(:custom_emoji).permit(:shortcode, :image, :category_id, :visible_in_picker, :aliases_raw, :license)
    end

    def update_params
      params.require(:custom_emoji).permit(:category_id, :visible_in_picker, :aliases_raw, :license)
    end

    def filtered_custom_emojis
      CustomEmojiFilter.new(filter_params).results
    end

    def filter_params
      params.slice(:page, *CustomEmojiFilter::KEYS).permit(:page, *CustomEmojiFilter::KEYS)
    end

    def action_from_button
      if params[:update]
        'update'
      elsif params[:list]
        'list'
      elsif params[:unlist]
        'unlist'
      elsif params[:enable]
        'enable'
      elsif params[:disable]
        'disable'
      elsif params[:copy]
        'copy'
      elsif params[:delete]
        'delete'
      end
    end

    def form_custom_emoji_batch_params
      params.require(:form_custom_emoji_batch).permit(:action, :category_id, :category_name, custom_emoji_ids: [])
    end
  end
end
