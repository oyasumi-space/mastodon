import { useEffect, useState, useCallback } from 'react';

import { FormattedMessage, useIntl, defineMessages } from 'react-intl';

import { isFulfilled } from '@reduxjs/toolkit';

import BookmarkIcon from '@/material-icons/400-24px/bookmark-fill.svg?react';
import CloseIcon from '@/material-icons/400-24px/close.svg?react';
import {
  bookmarkCategoryEditorAddSuccess,
  bookmarkCategoryEditorRemoveSuccess,
  fetchBookmarkCategories,
} from 'mastodon/actions/bookmark_categories';
import { createBookmarkCategory } from 'mastodon/actions/bookmark_categories_typed';
import { unbookmark } from 'mastodon/actions/interactions';
import {
  apiGetStatusBookmarkCategories,
  apiAddStatusToBookmarkCategory,
  apiRemoveStatusFromBookmarkCategory,
} from 'mastodon/api/bookmark_categories';
import type { ApiBookmarkCategoryJSON } from 'mastodon/api_types/bookmark_categories';
import { Button } from 'mastodon/components/button';
import { CheckBox } from 'mastodon/components/check_box';
import { Icon } from 'mastodon/components/icon';
import { IconButton } from 'mastodon/components/icon_button';
import { bookmarkCategoryNeeded } from 'mastodon/initial_state';
import { getOrderedBookmarkCategories } from 'mastodon/selectors/bookmark_categories';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  newBookmarkCategory: {
    id: 'bookmark_categories.new_bookmark_category_name',
    defaultMessage: 'New bookmark_category name',
  },
  createBookmarkCategory: {
    id: 'bookmark_categories.create',
    defaultMessage: 'Create',
  },
  close: {
    id: 'lightbox.close',
    defaultMessage: 'Close',
  },
});

const BookmarkCategoryItem: React.FC<{
  id: string;
  title: string;
  checked: boolean;
  onChange: (id: string, checked: boolean) => void;
}> = ({ id, title, checked, onChange }) => {
  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onChange(id, e.target.checked);
    },
    [id, onChange],
  );

  return (
    // eslint-disable-next-line jsx-a11y/label-has-associated-control
    <label className='lists__item'>
      <div className='lists__item__title'>
        <Icon id='bookmark_category-ul' icon={BookmarkIcon} />
        <span>{title}</span>
      </div>

      <CheckBox value={id} checked={checked} onChange={handleChange} />
    </label>
  );
};

const NewBookmarkCategoryItem: React.FC<{
  onCreate: (bookmark_category: ApiBookmarkCategoryJSON) => void;
}> = ({ onCreate }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const [title, setTitle] = useState('');

  const handleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setTitle(value);
    },
    [setTitle],
  );

  const handleSubmit = useCallback(() => {
    if (title.trim().length === 0) {
      return;
    }

    void dispatch(createBookmarkCategory({ title })).then((result) => {
      if (isFulfilled(result)) {
        onCreate(result.payload);
        setTitle('');
      }

      return '';
    });
  }, [setTitle, dispatch, onCreate, title]);

  return (
    <form className='lists__item' onSubmit={handleSubmit}>
      <label className='lists__item__title'>
        <Icon id='bookmark_category-ul' icon={BookmarkIcon} />

        <input
          type='text'
          value={title}
          onChange={handleChange}
          maxLength={30}
          required
          placeholder={intl.formatMessage(messages.newBookmarkCategory)}
        />
      </label>

      <Button
        text={intl.formatMessage(messages.createBookmarkCategory)}
        type='submit'
      />
    </form>
  );
};

const BookmarkCategoryAdder: React.FC<{
  statusId: string;
  onClose: () => void;
}> = ({ statusId, onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const bookmark_categories = useAppSelector((state) =>
    getOrderedBookmarkCategories(state),
  );
  // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-return
  const status = useAppSelector((state) => state.statuses.get(statusId));
  const [bookmark_categoryIds, setBookmarkCategoryIds] = useState<string[]>(
    [] as string[],
  );

  useEffect(() => {
    dispatch(fetchBookmarkCategories());

    apiGetStatusBookmarkCategories(statusId)
      .then((data) => {
        setBookmarkCategoryIds(data.map((l) => l.id));
        return '';
      })
      .catch(() => {
        // Nothing
      });
  }, [dispatch, setBookmarkCategoryIds, statusId]);

  const handleToggle = useCallback(
    (bookmark_categoryId: string, checked: boolean) => {
      if (checked) {
        setBookmarkCategoryIds((currentBookmarkCategoryIds) => [
          bookmark_categoryId,
          ...currentBookmarkCategoryIds,
        ]);

        apiAddStatusToBookmarkCategory(bookmark_categoryId, statusId)
          .then(() => {
            dispatch(
              bookmarkCategoryEditorAddSuccess(bookmark_categoryId, statusId),
            );
            return true;
          })
          .catch(() => {
            setBookmarkCategoryIds((currentBookmarkCategoryIds) =>
              currentBookmarkCategoryIds.filter(
                (id) => id !== bookmark_categoryId,
              ),
            );
          });
      } else {
        setBookmarkCategoryIds((currentBookmarkCategoryIds) =>
          currentBookmarkCategoryIds.filter((id) => id !== bookmark_categoryId),
        );

        apiRemoveStatusFromBookmarkCategory(bookmark_categoryId, statusId)
          .then(() => {
            dispatch(
              bookmarkCategoryEditorRemoveSuccess(
                bookmark_categoryId,
                statusId,
              ),
            );

            if (
              bookmarkCategoryNeeded &&
              bookmark_categoryIds.filter((id) => id !== bookmark_categoryId)
                .length === 0
            ) {
              dispatch(unbookmark(status));
            }

            return true;
          })
          .catch(() => {
            setBookmarkCategoryIds((currentBookmarkCategoryIds) => [
              bookmark_categoryId,
              ...currentBookmarkCategoryIds,
            ]);
          });
      }
    },
    [setBookmarkCategoryIds, statusId, dispatch, bookmark_categoryIds, status],
  );

  const handleCreate = useCallback(
    (bookmark_category: ApiBookmarkCategoryJSON) => {
      setBookmarkCategoryIds((currentBookmarkCategoryIds) => [
        bookmark_category.id,
        ...currentBookmarkCategoryIds,
      ]);

      apiAddStatusToBookmarkCategory(bookmark_category.id, statusId).catch(
        () => {
          setBookmarkCategoryIds((currentBookmarkCategoryIds) =>
            currentBookmarkCategoryIds.filter(
              (id) => id !== bookmark_category.id,
            ),
          );
        },
      );
    },
    [setBookmarkCategoryIds, statusId],
  );

  return (
    <div className='modal-root__modal dialog-modal'>
      <div className='dialog-modal__header'>
        <IconButton
          className='dialog-modal__header__close'
          title={intl.formatMessage(messages.close)}
          icon='times'
          iconComponent={CloseIcon}
          onClick={onClose}
        />

        <span className='dialog-modal__header__title'>
          <FormattedMessage
            id='bookmark_categories.add_to_bookmark_categories'
            defaultMessage='Add {name} to bookmark_categories'
            values={{ name: <strong>@</strong> }}
          />
        </span>
      </div>

      <div className='dialog-modal__content'>
        <div className='lists-scrollable'>
          <NewBookmarkCategoryItem onCreate={handleCreate} />

          {bookmark_categories.map((bookmark_category) => (
            <BookmarkCategoryItem
              key={bookmark_category.id}
              id={bookmark_category.id}
              title={bookmark_category.title}
              checked={bookmark_categoryIds.includes(bookmark_category.id)}
              onChange={handleToggle}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

// eslint-disable-next-line import/no-default-export
export default BookmarkCategoryAdder;
