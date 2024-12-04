import { createSelector } from '@reduxjs/toolkit';
import type { Map as ImmutableMap } from 'immutable';

import type { Antenna } from 'mastodon/models/antenna';
import type { RootState } from 'mastodon/store';

export const getOrderedAntennas = createSelector(
  [(state: RootState) => state.antennas],
  (antennas: ImmutableMap<string, Antenna | null>) =>
    antennas
      .toList()
      .filter((item: Antenna | null) => !!item)
      .sort((a: Antenna, b: Antenna) => a.title.localeCompare(b.title))
      .toArray(),
);
