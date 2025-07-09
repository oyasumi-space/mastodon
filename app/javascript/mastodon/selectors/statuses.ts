import { createSelector } from '@reduxjs/toolkit';
import type { OrderedSet as ImmutableOrderedSet } from 'immutable';
import { List as ImmutableList } from 'immutable';

import type { RootState } from 'mastodon/store';

export const getStatusList = createSelector(
  [
    (
      state: RootState,
      type:
        | 'favourites'
        | 'bookmarks'
        | 'pins'
        | 'trending'
        | 'emoji_reactions',
    ) =>
      state.status_lists.getIn([type, 'items']) as ImmutableOrderedSet<string>,
  ],
  (items) => items.toList(),
);

export const getSubStatusList = createSelector(
  [
    (state: RootState, type: 'bookmark_category' | 'circle', id: string) =>
      state.status_lists.getIn([
        `${type}_statuses`,
        id,
        'items',
      ]) as ImmutableOrderedSet<string> | null,
  ],
  (items) => (items ? items.toList() : ImmutableList()),
);
