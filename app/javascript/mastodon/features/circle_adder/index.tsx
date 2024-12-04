import { useEffect, useState, useCallback } from 'react';

import { FormattedMessage, useIntl, defineMessages } from 'react-intl';

import { isFulfilled } from '@reduxjs/toolkit';

import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import CloseIcon from '@/material-icons/400-24px/close.svg?react';
import { fetchCircles } from 'mastodon/actions/circles';
import { createCircle } from 'mastodon/actions/circles_typed';
import {
  apiGetAccountCircles,
  apiAddAccountToCircle,
  apiRemoveAccountFromCircle,
} from 'mastodon/api/circles';
import type { ApiCircleJSON } from 'mastodon/api_types/circles';
import { Button } from 'mastodon/components/button';
import { CheckBox } from 'mastodon/components/check_box';
import { Icon } from 'mastodon/components/icon';
import { IconButton } from 'mastodon/components/icon_button';
import { getOrderedCircles } from 'mastodon/selectors/circles';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  newCircle: {
    id: 'circles.new_circle_name',
    defaultMessage: 'New circle name',
  },
  createCircle: {
    id: 'circles.create',
    defaultMessage: 'Create',
  },
  close: {
    id: 'lightbox.close',
    defaultMessage: 'Close',
  },
});

const CircleItem: React.FC<{
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
        <Icon id='circle-ul' icon={CircleIcon} />
        <span>{title}</span>
      </div>

      <CheckBox value={id} checked={checked} onChange={handleChange} />
    </label>
  );
};

const NewCircleItem: React.FC<{
  onCreate: (circle: ApiCircleJSON) => void;
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

    void dispatch(createCircle({ title })).then((result) => {
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
        <Icon id='circle-ul' icon={CircleIcon} />

        <input
          type='text'
          value={title}
          onChange={handleChange}
          maxLength={30}
          required
          placeholder={intl.formatMessage(messages.newCircle)}
        />
      </label>

      <Button text={intl.formatMessage(messages.createCircle)} type='submit' />
    </form>
  );
};

const CircleAdder: React.FC<{
  accountId: string;
  onClose: () => void;
}> = ({ accountId, onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const account = useAppSelector((state) => state.accounts.get(accountId));
  const circles = useAppSelector((state) => getOrderedCircles(state));
  const [circleIds, setCircleIds] = useState<string[]>([]);

  useEffect(() => {
    dispatch(fetchCircles());

    apiGetAccountCircles(accountId)
      .then((data) => {
        setCircleIds(data.map((l) => l.id));
        return '';
      })
      .catch(() => {
        // Nothing
      });
  }, [dispatch, setCircleIds, accountId]);

  const handleToggle = useCallback(
    (circleId: string, checked: boolean) => {
      if (checked) {
        setCircleIds((currentCircleIds) => [circleId, ...currentCircleIds]);

        apiAddAccountToCircle(circleId, accountId).catch(() => {
          setCircleIds((currentCircleIds) =>
            currentCircleIds.filter((id) => id !== circleId),
          );
        });
      } else {
        setCircleIds((currentCircleIds) =>
          currentCircleIds.filter((id) => id !== circleId),
        );

        apiRemoveAccountFromCircle(circleId, accountId).catch(() => {
          setCircleIds((currentCircleIds) => [circleId, ...currentCircleIds]);
        });
      }
    },
    [setCircleIds, accountId],
  );

  const handleCreate = useCallback(
    (circle: ApiCircleJSON) => {
      setCircleIds((currentCircleIds) => [circle.id, ...currentCircleIds]);

      apiAddAccountToCircle(circle.id, accountId).catch(() => {
        setCircleIds((currentCircleIds) =>
          currentCircleIds.filter((id) => id !== circle.id),
        );
      });
    },
    [setCircleIds, accountId],
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
            id='circles.add_to_circles'
            defaultMessage='Add {name} to circles'
            values={{ name: <strong>@{account?.acct}</strong> }}
          />
        </span>
      </div>

      <div className='dialog-modal__content'>
        <div className='lists-scrollable'>
          <NewCircleItem onCreate={handleCreate} />

          {circles.map((circle) => (
            <CircleItem
              key={circle.id}
              id={circle.id}
              title={circle.title}
              checked={circleIds.includes(circle.id)}
              onChange={handleToggle}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

// eslint-disable-next-line import/no-default-export
export default CircleAdder;
