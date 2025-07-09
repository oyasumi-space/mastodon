import type { Map as ImmutableMap, List as ImmutableList } from 'immutable';

import type { BookmarkCategory } from 'mastodon/models/bookmark_category';
import { createAppSelector } from 'mastodon/store';

const getBookmarkCategories = createAppSelector(
  [(state) => state.bookmark_categories],
  (
    bookmark_categories: ImmutableMap<string, BookmarkCategory | null>,
  ): ImmutableList<BookmarkCategory> =>
    bookmark_categories
      .toList()
      .filter(
        (item: BookmarkCategory | null): item is BookmarkCategory => !!item,
      ),
);

export const getOrderedBookmarkCategories = createAppSelector(
  [(state) => getBookmarkCategories(state)],
  (bookmark_categories) =>
    bookmark_categories
      .sort((a: BookmarkCategory, b: BookmarkCategory) =>
        a.title.localeCompare(b.title),
      )
      .toArray(),
);
