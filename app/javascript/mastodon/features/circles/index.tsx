import { useEffect, useMemo, useCallback } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';
import { Link } from 'react-router-dom';

import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import AddIcon from '@/material-icons/400-24px/add.svg?react';
import MoreHorizIcon from '@/material-icons/400-24px/more_horiz.svg?react';
import SquigglyArrow from '@/svg-icons/squiggly_arrow.svg?react';
import { fetchCircles } from 'mastodon/actions/circles';
import { openModal } from 'mastodon/actions/modal';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { Icon } from 'mastodon/components/icon';
import ScrollableList from 'mastodon/components/scrollable_list';
import DropdownMenuContainer from 'mastodon/containers/dropdown_menu_container';
import { getOrderedCircles } from 'mastodon/selectors/circles';
import { useAppSelector, useAppDispatch } from 'mastodon/store';

const messages = defineMessages({
  heading: { id: 'column.circles', defaultMessage: 'Circles' },
  create: { id: 'circles.create_circle', defaultMessage: 'Create circle' },
  edit: { id: 'circles.edit', defaultMessage: 'Edit circle' },
  delete: { id: 'circles.delete', defaultMessage: 'Delete circle' },
  more: { id: 'status.more', defaultMessage: 'More' },
});

const CircleItem: React.FC<{
  id: string;
  title: string;
}> = ({ id, title }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();

  const handleDeleteClick = useCallback(() => {
    dispatch(
      openModal({
        modalType: 'CONFIRM_DELETE_CIRCLE',
        modalProps: {
          circleId: id,
        },
      }),
    );
  }, [dispatch, id]);

  const menu = useMemo(
    () => [
      { text: intl.formatMessage(messages.edit), to: `/circles/${id}/edit` },
      { text: intl.formatMessage(messages.delete), action: handleDeleteClick },
    ],
    [intl, id, handleDeleteClick],
  );

  return (
    <div className='lists__item'>
      <Link to={`/circles/${id}`} className='lists__item__title'>
        <Icon id='circle-ul' icon={CircleIcon} />
        <span>{title}</span>
      </Link>

      <DropdownMenuContainer
        scrollKey='circles'
        items={menu}
        icons='ellipsis-h'
        iconComponent={MoreHorizIcon}
        direction='right'
        title={intl.formatMessage(messages.more)}
      />
    </div>
  );
};

const Circles: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();
  const circles = useAppSelector((state) => getOrderedCircles(state));

  useEffect(() => {
    dispatch(fetchCircles());
  }, [dispatch]);

  const emptyMessage = (
    <>
      <span>
        <FormattedMessage
          id='circles.no_circles_yet'
          defaultMessage='No circles yet.'
        />
        <br />
        <FormattedMessage
          id='circles.create_a_circle_to_organize'
          defaultMessage='Create a new circle to organize your Home feed'
        />
      </span>

      <SquigglyArrow className='empty-column-indicator__arrow' />
    </>
  );

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(messages.heading)}
    >
      <ColumnHeader
        title={intl.formatMessage(messages.heading)}
        icon='circle-ul'
        iconComponent={CircleIcon}
        multiColumn={multiColumn}
        extraButton={
          <Link
            to='/circles/new'
            className='column-header__button'
            title={intl.formatMessage(messages.create)}
            aria-label={intl.formatMessage(messages.create)}
          >
            <Icon id='plus' icon={AddIcon} />
          </Link>
        }
      />

      <ScrollableList
        scrollKey='circles'
        emptyMessage={emptyMessage}
        bindToDocument={!multiColumn}
      >
        {circles.map((circle) => (
          <CircleItem key={circle.id} id={circle.id} title={circle.title} />
        ))}
      </ScrollableList>

      <Helmet>
        <title>{intl.formatMessage(messages.heading)}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default Circles;
