import api, { getAsyncRefreshHeader } from 'mastodon/api';
import type { ApiContextJSON } from 'mastodon/api_types/statuses';

export const apiGetContext = async (statusId: string) => {
  const response = await api().request<ApiContextJSON>({
    method: 'GET',
    url: `/api/v1/statuses/${statusId}/context?with_reference=1`,
  });

  return {
    context: response.data,
    refresh: getAsyncRefreshHeader(response),
  };
};
