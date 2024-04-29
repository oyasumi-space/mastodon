import { List as ImmutableList, fromJS } from 'immutable';

import {
  CIRCLE_FETCH_SUCCESS,
  CIRCLE_FETCH_FAIL,
  CIRCLES_FETCH_SUCCESS,
  CIRCLE_CREATE_SUCCESS,
  CIRCLE_UPDATE_SUCCESS,
  CIRCLE_DELETE_SUCCESS,
} from '../actions/circles';

const initialState = ImmutableList();

const normalizeList = (state, circle) => state.set(circle.id, fromJS(circle));

const normalizeLists = (state, circles) => {
  circles.forEach(circle => {
    state = normalizeList(state, circle);
  });

  return state;
};

export default function circles(state = initialState, action) {
  switch(action.type) {
  case CIRCLE_FETCH_SUCCESS:
  case CIRCLE_CREATE_SUCCESS:
  case CIRCLE_UPDATE_SUCCESS:
    return normalizeList(state, action.circle);
  case CIRCLES_FETCH_SUCCESS:
    return normalizeLists(state, action.circles);
  case CIRCLE_DELETE_SUCCESS:
  case CIRCLE_FETCH_FAIL:
    return state.set(action.id, false);
  default:
    return state;
  }
}
