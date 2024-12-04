import {
  apiRequestPost,
  apiRequestPut,
  apiRequestGet,
  apiRequestDelete,
} from 'mastodon/api';
import type { ApiAccountJSON } from 'mastodon/api_types/accounts';
import type { ApiBookmarkCategoryJSON } from 'mastodon/api_types/bookmark_categories';

export const apiCreate = (bookmarkCategory: Partial<ApiBookmarkCategoryJSON>) =>
  apiRequestPost<ApiBookmarkCategoryJSON>(
    'v1/bookmark_categories',
    bookmarkCategory,
  );

export const apiUpdate = (bookmarkCategory: Partial<ApiBookmarkCategoryJSON>) =>
  apiRequestPut<ApiBookmarkCategoryJSON>(
    `v1/bookmark_categories/${bookmarkCategory.id}`,
    bookmarkCategory,
  );

export const apiGetStatuses = (bookmarkCategoryId: string) =>
  apiRequestGet<ApiAccountJSON[]>(
    `v1/bookmark_categories/${bookmarkCategoryId}/statuses`,
    {
      limit: 0,
    },
  );

export const apiGetStatusBookmarkCategories = (accountId: string) =>
  apiRequestGet<ApiBookmarkCategoryJSON[]>(
    `v1/statuses/${accountId}/bookmark_categories`,
  );

export const apiAddStatusToBookmarkCategory = (
  bookmarkCategoryId: string,
  statusId: string,
) =>
  apiRequestPost(`v1/bookmark_categories/${bookmarkCategoryId}/statuses`, {
    status_ids: [statusId],
  });

export const apiRemoveStatusFromBookmarkCategory = (
  bookmarkCategoryId: string,
  statusId: string,
) =>
  apiRequestDelete(`v1/bookmark_categories/${bookmarkCategoryId}/statuses`, {
    status_ids: [statusId],
  });
