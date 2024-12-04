import { createSelector } from '@reduxjs/toolkit';
import type { Map as ImmutableMap } from 'immutable';

import type { BookmarkCategory } from 'mastodon/models/bookmark_category';
import type { RootState } from 'mastodon/store';

export const getOrderedBookmarkCategories = createSelector(
  [(state: RootState) => state.bookmark_categories],
  (bookmark_categories: ImmutableMap<string, BookmarkCategory | null>) =>
    bookmark_categories
      .toList()
      .filter((item: BookmarkCategory | null) => !!item)
      .sort((a: BookmarkCategory, b: BookmarkCategory) =>
        a.title.localeCompare(b.title),
      )
      .toArray(),
);
