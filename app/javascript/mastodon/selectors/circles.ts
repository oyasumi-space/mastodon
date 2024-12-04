import { createSelector } from '@reduxjs/toolkit';
import type { Map as ImmutableMap } from 'immutable';

import type { Circle } from 'mastodon/models/circle';
import type { RootState } from 'mastodon/store';

export const getOrderedCircles = createSelector(
  [(state: RootState) => state.circles],
  (circles: ImmutableMap<string, Circle | null>) =>
    circles
      .toList()
      .filter((item: Circle | null) => !!item)
      .sort((a: Circle, b: Circle) => a.title.localeCompare(b.title))
      .toArray(),
);
