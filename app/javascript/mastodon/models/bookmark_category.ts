import type { RecordOf } from 'immutable';
import { Record } from 'immutable';

import type { ApiBookmarkCategoryJSON } from 'mastodon/api_types/bookmark_categories';

type BookmarkCategoryShape = Required<ApiBookmarkCategoryJSON>; // no changes from server shape
export type BookmarkCategory = RecordOf<BookmarkCategoryShape>;

const BookmarkCategoryFactory = Record<BookmarkCategoryShape>({
  id: '',
  title: '',
});

export function createBookmarkCategory(
  attributes: Partial<BookmarkCategoryShape>,
) {
  return BookmarkCategoryFactory(attributes);
}
