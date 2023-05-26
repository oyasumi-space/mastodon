import { Map as ImmutableMap, List as ImmutableList, fromJS } from 'immutable';

import { STATUS_IMPORT, STATUSES_IMPORT } from '../actions/importer';
import {
  REBLOG_REQUEST,
  REBLOG_FAIL,
  FAVOURITE_REQUEST,
  FAVOURITE_FAIL,
  UNFAVOURITE_SUCCESS,
  BOOKMARK_REQUEST,
  BOOKMARK_FAIL,
} from '../actions/interactions';
import {
  STATUS_MUTE_SUCCESS,
  STATUS_UNMUTE_SUCCESS,
  STATUS_REVEAL,
  STATUS_HIDE,
  STATUS_COLLAPSE,
  STATUS_TRANSLATE_SUCCESS,
  STATUS_TRANSLATE_UNDO,
  STATUS_FETCH_REQUEST,
  STATUS_FETCH_FAIL,
  STATUS_EMOJI_REACTION_UPDATE,
} from '../actions/statuses';
import { TIMELINE_DELETE } from '../actions/timelines';

const importStatus = (state, status) => state.set(status.id, fromJS(status));

const importStatuses = (state, statuses) =>
  state.withMutations(mutable => statuses.forEach(status => importStatus(mutable, status)));

const deleteStatus = (state, id, references) => {
  references.forEach(ref => {
    state = deleteStatus(state, ref, []);
  });

  return state.delete(id);
};

const updateStatusEmojiReaction = (state, emoji_reaction, myId) => {
  emoji_reaction.me = emoji_reaction.account_ids ? emoji_reaction.account_ids.indexOf(myId) >= 0 : false;

  const status = state.get(emoji_reaction.status_id);
  if (!status) return state;

  let emoji_reactions = Array.from(status.get('emoji_reactions') || []);

  if (emoji_reaction.count > 0) {
    const old_emoji = emoji_reactions.find((er) => er.get('name') === emoji_reaction.name && (!er.get('domain') || er.get('domain') === emoji_reaction.domain));
    if (old_emoji) {
      const index = emoji_reactions.indexOf(old_emoji);
      emoji_reactions[index] = old_emoji.merge({ account_ids: emoji_reaction.account_ids, count: emoji_reaction.count, me: emoji_reaction.me });
    } else {
      emoji_reactions.push(ImmutableMap(emoji_reaction));
    }
  } else {
    emoji_reactions = emoji_reactions.filter((er) => er.get('name') !== emoji_reaction.name || er.get('domain') !== emoji_reaction.domain);
  }

  return state.setIn([emoji_reaction.status_id, 'emoji_reactions'], ImmutableList(emoji_reactions));
};

const initialState = ImmutableMap();

export default function statuses(state = initialState, action) {
  switch(action.type) {
  case STATUS_FETCH_REQUEST:
    return state.setIn([action.id, 'isLoading'], true);
  case STATUS_FETCH_FAIL:
    return state.delete(action.id);
  case STATUS_IMPORT:
    return importStatus(state, action.status);
  case STATUSES_IMPORT:
    return importStatuses(state, action.statuses);
  case FAVOURITE_REQUEST:
    return state.setIn([action.status.get('id'), 'favourited'], true);
  case UNFAVOURITE_SUCCESS:
    return state.updateIn([action.status.get('id'), 'favourites_count'], x => Math.max(0, x - 1));
  case FAVOURITE_FAIL:
    return state.get(action.status.get('id')) === undefined ? state : state.setIn([action.status.get('id'), 'favourited'], false);
  case BOOKMARK_REQUEST:
    return state.get(action.status.get('id')) === undefined ? state : state.setIn([action.status.get('id'), 'bookmarked'], true);
  case BOOKMARK_FAIL:
    return state.get(action.status.get('id')) === undefined ? state : state.setIn([action.status.get('id'), 'bookmarked'], false);
  case REBLOG_REQUEST:
    return state.setIn([action.status.get('id'), 'reblogged'], true);
  case REBLOG_FAIL:
    return state.get(action.status.get('id')) === undefined ? state : state.setIn([action.status.get('id'), 'reblogged'], false);
  case STATUS_MUTE_SUCCESS:
    return state.setIn([action.id, 'muted'], true);
  case STATUS_UNMUTE_SUCCESS:
    return state.setIn([action.id, 'muted'], false);
  case STATUS_REVEAL:
    return state.withMutations(map => {
      action.ids.forEach(id => {
        if (!(state.get(id) === undefined)) {
          map.setIn([id, 'hidden'], false);
        }
      });
    });
  case STATUS_HIDE:
    return state.withMutations(map => {
      action.ids.forEach(id => {
        if (!(state.get(id) === undefined)) {
          map.setIn([id, 'hidden'], true);
        }
      });
    });
  case STATUS_COLLAPSE:
    return state.setIn([action.id, 'collapsed'], action.isCollapsed);
  case TIMELINE_DELETE:
    return deleteStatus(state, action.id, action.references);
  case STATUS_TRANSLATE_SUCCESS:
    return state.setIn([action.id, 'translation'], fromJS(action.translation));
  case STATUS_TRANSLATE_UNDO:
    return state.deleteIn([action.id, 'translation']);
  case STATUS_EMOJI_REACTION_UPDATE:
    return updateStatusEmojiReaction(state, action.emoji_reaction, action.accountId);
  default:
    return state;
  }
}
