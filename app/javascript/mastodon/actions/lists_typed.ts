import { apiCreate, apiUpdate } from 'mastodon/api/lists';
import type { List } from 'mastodon/models/list';
import { createDataLoadingThunk } from 'mastodon/store/typed_functions';

export const createList = createDataLoadingThunk(
  'list/create',
  (list: Partial<List>) => apiCreate(list),
);

// Kmyblue tracking marker: copied antenna, circle, bookmark_category

export const updateList = createDataLoadingThunk(
  'list/update',
  (list: Partial<List>) => apiUpdate(list),
);

// Kmyblue tracking marker: copied antenna, circle, bookmark_category
