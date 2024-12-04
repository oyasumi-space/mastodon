import { apiCreate, apiUpdate } from 'mastodon/api/circles';
import type { Circle } from 'mastodon/models/circle';
import { createDataLoadingThunk } from 'mastodon/store/typed_functions';

export const createCircle = createDataLoadingThunk(
  'circle/create',
  (circle: Partial<Circle>) => apiCreate(circle),
);

export const updateCircle = createDataLoadingThunk(
  'circle/update',
  (circle: Partial<Circle>) => apiUpdate(circle),
);
