import { useCallback } from 'react';

import { defineMessages, useIntl } from 'react-intl';

import { useHistory } from 'react-router';

import { deleteBookmarkCategory } from 'mastodon/actions/bookmark_categories';
import { removeColumn } from 'mastodon/actions/columns';
import { useAppDispatch } from 'mastodon/store';

import type { BaseConfirmationModalProps } from './confirmation_modal';
import { ConfirmationModal } from './confirmation_modal';

const messages = defineMessages({
  deleteBookmarkCategoryTitle: {
    id: 'confirmations.delete_bookmark_category.title',
    defaultMessage: 'Delete category?',
  },
  deleteBookmarkCategoryMessage: {
    id: 'confirmations.delete_bookmark_category.message',
    defaultMessage:
      'Are you sure you want to permanently delete this category?',
  },
  deleteBookmarkCategoryConfirm: {
    id: 'confirmations.delete_bookmark_category.confirm',
    defaultMessage: 'Delete',
  },
});

export const ConfirmDeleteBookmarkCategoryModal: React.FC<
  {
    bookmark_categoryId: string;
    columnId: string;
  } & BaseConfirmationModalProps
> = ({ bookmark_categoryId, columnId, onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const history = useHistory();

  const onConfirm = useCallback(() => {
    dispatch(deleteBookmarkCategory(bookmark_categoryId));

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      history.push('/bookmark_categories');
    }
  }, [dispatch, history, columnId, bookmark_categoryId]);

  return (
    <ConfirmationModal
      title={intl.formatMessage(messages.deleteBookmarkCategoryTitle)}
      message={intl.formatMessage(messages.deleteBookmarkCategoryMessage)}
      confirm={intl.formatMessage(messages.deleteBookmarkCategoryConfirm)}
      onConfirm={onConfirm}
      onClose={onClose}
    />
  );
};
