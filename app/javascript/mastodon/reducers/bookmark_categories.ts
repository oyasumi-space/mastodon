import type { Reducer } from '@reduxjs/toolkit';
import { Map as ImmutableMap } from 'immutable';

import {
  createBookmarkCategory,
  updateBookmarkCategory,
} from 'mastodon/actions/bookmark_categories_typed';
import type { ApiBookmarkCategoryJSON } from 'mastodon/api_types/bookmark_categories';
import { createBookmarkCategory as createBookmarkCategoryFromJSON } from 'mastodon/models/bookmark_category';
import type { BookmarkCategory } from 'mastodon/models/bookmark_category';

import {
  BOOKMARK_CATEGORY_FETCH_SUCCESS,
  BOOKMARK_CATEGORY_FETCH_FAIL,
  BOOKMARK_CATEGORIES_FETCH_SUCCESS,
  BOOKMARK_CATEGORY_DELETE_SUCCESS,
} from '../actions/bookmark_categories';

const initialState = ImmutableMap<string, BookmarkCategory | null>();
type State = typeof initialState;

const normalizeBookmarkCategory = (
  state: State,
  bookmark_category: ApiBookmarkCategoryJSON,
) =>
  state.set(
    bookmark_category.id,
    createBookmarkCategoryFromJSON(bookmark_category),
  );

const normalizeBookmarkCategories = (
  state: State,
  bookmark_categories: ApiBookmarkCategoryJSON[],
) => {
  bookmark_categories.forEach((bookmark_category) => {
    state = normalizeBookmarkCategory(state, bookmark_category);
  });

  return state;
};

export const bookmarkCategoriesReducer: Reducer<State> = (
  state = initialState,
  action,
) => {
  if (
    createBookmarkCategory.fulfilled.match(action) ||
    updateBookmarkCategory.fulfilled.match(action)
  ) {
    return normalizeBookmarkCategory(state, action.payload);
  } else {
    switch (action.type) {
      case BOOKMARK_CATEGORY_FETCH_SUCCESS:
        return normalizeBookmarkCategory(
          state,
          action.bookmarkCategory as ApiBookmarkCategoryJSON,
        );
      case BOOKMARK_CATEGORIES_FETCH_SUCCESS:
        return normalizeBookmarkCategories(
          state,
          action.bookmarkCategories as ApiBookmarkCategoryJSON[],
        );
      case BOOKMARK_CATEGORY_DELETE_SUCCESS:
      case BOOKMARK_CATEGORY_FETCH_FAIL:
        return state.set(action.id as string, null);
      default:
        return state;
    }
  }
};
