import { injectIntl } from 'react-intl';

import { connect } from 'react-redux';

import {
  unmuteAccount,
  unblockAccount,
} from '../actions/accounts';
import { initBlockModal } from '../actions/blocks';
import {
  replyCompose,
  mentionCompose,
  directCompose,
  insertReferenceCompose,
} from '../actions/compose';
import {
  initDomainBlockModal,
  unblockDomain,
} from '../actions/domain_blocks';
import {
  initAddFilter,
} from '../actions/filters';
import {
  emojiReact,
  unEmojiReact,
  toggleReblog,
  toggleFavourite,
  bookmark,
  unbookmark,
  pin,
  unpin,
} from '../actions/interactions';
import { openModal } from '../actions/modal';
import { initMuteModal } from '../actions/mutes';
import { deployPictureInPicture } from '../actions/picture_in_picture';
import { initReport } from '../actions/reports';
import {
  muteStatus,
  unmuteStatus,
  deleteStatus,
  toggleStatusSpoilers,
  toggleStatusCollapse,
  editStatus,
  translateStatus,
  undoStatusTranslation,
} from '../actions/statuses';
import Status from '../components/status';
import { deleteModal } from '../initial_state';
import { makeGetStatus, makeGetPictureInPicture } from '../selectors';

const makeMapStateToProps = () => {
  const getStatus = makeGetStatus();
  const getPictureInPicture = makeGetPictureInPicture();

  const mapStateToProps = (state, props) => ({
    status: getStatus(state, props),
    nextInReplyToId: props.nextId ? state.getIn(['statuses', props.nextId, 'in_reply_to_id']) : null,
    pictureInPicture: getPictureInPicture(state, props),
  });

  return mapStateToProps;
};

const mapDispatchToProps = (dispatch, { contextType }) => ({

  contextType,

  onReply (status) {
    dispatch((_, getState) => {
      let state = getState();

      if (state.getIn(['compose', 'text']).trim().length !== 0) {
        dispatch(openModal({ modalType: 'CONFIRM_REPLY', modalProps: { status } }));
      } else {
        dispatch(replyCompose(status));
      }
    });
  },

  onReblog (status, e) {
    dispatch(toggleReblog(status.get('id'), e?.shiftKey || false));
  },

  onReblogForceModal (status) {
    dispatch(toggleReblog(status.get('id'), false, true));
  },

  onFavourite (status) {
    dispatch(toggleFavourite(status.get('id')));
  },

  onEmojiReact (status, emoji) {
    dispatch(emojiReact(status, emoji));
  },

  onUnEmojiReact (status, emoji) {
    dispatch(unEmojiReact(status, emoji));
  },

  onBookmark (status) {
    if (status.get('bookmarked')) {
      dispatch(unbookmark(status));
    } else {
      dispatch(bookmark(status));
    }
  },

  onBookmarkCategoryAdder (status) {
    dispatch(openModal({
      modalType: 'BOOKMARK_CATEGORY_ADDER',
      modalProps: {
        statusId: status.get('id'),
      },
    }));
  },

  onPin (status) {
    if (status.get('pinned')) {
      dispatch(unpin(status));
    } else {
      dispatch(pin(status));
    }
  },

  onEmbed (status) {
    dispatch(openModal({
      modalType: 'EMBED',
      modalProps: { id: status.get('id') },
    }));
  },

  onDelete (status, withRedraft = false) {
    if (!deleteModal) {
      dispatch(deleteStatus(status.get('id'), withRedraft));
    } else {
      dispatch(openModal({ modalType: 'CONFIRM_DELETE_STATUS', modalProps: { statusId: status.get('id'), withRedraft } }));
    }
  },

  onEdit (status) {
    dispatch((_, getState) => {
      let state = getState();
      if (state.getIn(['compose', 'text']).trim().length !== 0) {
        dispatch(openModal({ modalType: 'CONFIRM_EDIT_STATUS', modalProps: { statusId: status.get('id') } }));
      } else {
        dispatch(editStatus(status.get('id')));
      }
    });
  },

  onReference (status, router) {
    dispatch(insertReferenceCompose(0, status.get('url'), 'BT', router));
  },

  onQuote (status, router) {
    dispatch(insertReferenceCompose(0, status.get('url'), 'QT', router));
  },

  onTranslate (status) {
    if (status.get('translation')) {
      dispatch(undoStatusTranslation(status.get('id'), status.get('poll')));
    } else {
      dispatch(translateStatus(status.get('id')));
    }
  },

  onDirect (account) {
    dispatch(directCompose(account));
  },

  onMention (account) {
    dispatch(mentionCompose(account));
  },

  onOpenMedia (statusId, media, index, lang) {
    dispatch(openModal({
      modalType: 'MEDIA',
      modalProps: { statusId, media, index, lang },
    }));
  },

  onOpenVideo (statusId, media, lang, options) {
    dispatch(openModal({
      modalType: 'VIDEO',
      modalProps: { statusId, media, lang, options },
    }));
  },

  onBlock (status) {
    const account = status.get('account');
    dispatch(initBlockModal(account));
  },

  onUnblock (account) {
    dispatch(unblockAccount(account.get('id')));
  },

  onReport (status) {
    dispatch(initReport(status.get('account'), status));
  },

  onAddFilter (status) {
    dispatch(initAddFilter(status, { contextType }));
  },

  onMute (account) {
    dispatch(initMuteModal(account));
  },

  onUnmute (account) {
    dispatch(unmuteAccount(account.get('id')));
  },

  onMuteConversation (status) {
    if (status.get('muted')) {
      dispatch(unmuteStatus(status.get('id')));
    } else {
      dispatch(muteStatus(status.get('id')));
    }
  },

  onToggleHidden (status) {
    dispatch(toggleStatusSpoilers(status.get('id')));
  },

  onToggleCollapsed (status, isCollapsed) {
    dispatch(toggleStatusCollapse(status.get('id'), isCollapsed));
  },

  onBlockDomain (account) {
    dispatch(initDomainBlockModal(account));
  },

  onUnblockDomain (domain) {
    dispatch(unblockDomain(domain));
  },

  deployPictureInPicture (status, type, mediaProps) {
    dispatch(deployPictureInPicture({statusId: status.get('id'), accountId: status.getIn(['account', 'id']), playerType: type, props: mediaProps}));
  },

  onInteractionModal (type, status) {
    dispatch(openModal({
      modalType: 'INTERACTION',
      modalProps: {
        type,
        accountId: status.getIn(['account', 'id']),
        url: status.get('uri'),
      },
    }));
  },

});

export default injectIntl(connect(makeMapStateToProps, mapDispatchToProps)(Status));
