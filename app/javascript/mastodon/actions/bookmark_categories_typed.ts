import { apiCreate, apiUpdate } from 'mastodon/api/bookmark_categories';
import type { BookmarkCategory } from 'mastodon/models/bookmark_category';
import { createDataLoadingThunk } from 'mastodon/store/typed_functions';

export const createBookmarkCategory = createDataLoadingThunk(
  'bookmark_category/create',
  (bookmarkCategory: Partial<BookmarkCategory>) => apiCreate(bookmarkCategory),
);

export const updateBookmarkCategory = createDataLoadingThunk(
  'bookmark_category/update',
  (bookmarkCategory: Partial<BookmarkCategory>) => apiUpdate(bookmarkCategory),
);
