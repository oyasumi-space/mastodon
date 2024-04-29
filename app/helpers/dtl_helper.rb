# frozen_string_literal: true

module DtlHelper
  DTL_ENABLED = ENV.fetch('DTL_ENABLED', 'false') == 'true'
  DTL_TAG = ENV.fetch('DTL_TAG', 'kmyblue')
end
