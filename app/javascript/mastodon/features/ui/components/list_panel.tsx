import { useEffect, useState, useCallback, useId } from 'react';

import { useIntl, defineMessages } from 'react-intl';

import ArrowDropDownIcon from '@/material-icons/400-24px/arrow_drop_down.svg?react';
import ArrowLeftIcon from '@/material-icons/400-24px/arrow_left.svg?react';
import ListAltActiveIcon from '@/material-icons/400-24px/list_alt-fill.svg?react';
import ListAltIcon from '@/material-icons/400-24px/list_alt.svg?react';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import { fetchAntennas } from 'mastodon/actions/antennas';
import { fetchLists } from 'mastodon/actions/lists';
import { IconButton } from 'mastodon/components/icon_button';
import { getOrderedAntennas } from 'mastodon/selectors/antennas';
import { getOrderedLists } from 'mastodon/selectors/lists';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import { ColumnLink } from './column_link';

const messages = defineMessages({
  lists: { id: 'navigation_bar.lists', defaultMessage: 'Lists' },
  antennas: { id: 'navigation_bar.antennas', defaultMessage: 'Antennas' },
  expand: {
    id: 'navigation_panel.expand_lists',
    defaultMessage: 'Expand list menu',
  },
  collapse: {
    id: 'navigation_panel.collapse_lists',
    defaultMessage: 'Collapse list menu',
  },
});

export const ListPanel: React.FC = () => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const lists = useAppSelector((state) => getOrderedLists(state));
  const antennas = useAppSelector((state) => getOrderedAntennas(state));
  const [expanded, setExpanded] = useState(false);
  const [expandedAntenna, setExpandedAntenna] = useState(false);
  const accessibilityId = useId();

  useEffect(() => {
    dispatch(fetchLists());
    dispatch(fetchAntennas());
  }, [dispatch]);

  const handleClick = useCallback(() => {
    setExpanded((value) => !value);
  }, [setExpanded]);

  const handleClickAntenna = useCallback(() => {
    setExpandedAntenna((value) => !value);
  }, [setExpandedAntenna]);

  return (
    <>
      <div className='navigation-panel__list-panel'>
        <div className='navigation-panel__list-panel__header'>
          <ColumnLink
            transparent
            to='/lists'
            icon='list-ul'
            iconComponent={ListAltIcon}
            activeIconComponent={ListAltActiveIcon}
            text={intl.formatMessage(messages.lists)}
            id={`${accessibilityId}-title`}
          />

          {lists.length > 0 && (
            <IconButton
              icon='down'
              expanded={expanded}
              iconComponent={expanded ? ArrowDropDownIcon : ArrowLeftIcon}
              title={intl.formatMessage(
                expanded ? messages.collapse : messages.expand,
              )}
              onClick={handleClick}
              aria-controls={`${accessibilityId}-content`}
            />
          )}
        </div>

        {lists.length > 0 && expanded && (
          <div
            className='navigation-panel__list-panel__items'
            role='region'
            id={`${accessibilityId}-content`}
            aria-labelledby={`${accessibilityId}-title`}
          >
            {lists.map((list) => (
              <ColumnLink
                icon='list-ul'
                key={list.get('id')}
                iconComponent={ListAltIcon}
                activeIconComponent={ListAltActiveIcon}
                text={list.get('title')}
                to={`/lists/${list.get('id')}`}
                transparent
              />
            ))}
          </div>
        )}
      </div>
      <div className='navigation-panel__list-panel'>
        <div className='navigation-panel__list-panel__header'>
          <ColumnLink
            transparent
            to='/antennas'
            icon='list-ul'
            iconComponent={AntennaIcon}
            activeIconComponent={AntennaIcon}
            text={intl.formatMessage(messages.antennas)}
            id={`${accessibilityId}-title`}
          />

          {antennas.length > 0 && (
            <IconButton
              icon='down'
              expanded={expanded}
              iconComponent={expanded ? ArrowDropDownIcon : ArrowLeftIcon}
              title={intl.formatMessage(
                expanded ? messages.collapse : messages.expand,
              )}
              onClick={handleClickAntenna}
              aria-controls={`${accessibilityId}-content`}
            />
          )}
        </div>

        {antennas.length > 0 && expandedAntenna && (
          <div
            className='navigation-panel__list-panel__items'
            role='region'
            id={`${accessibilityId}-content`}
            aria-labelledby={`${accessibilityId}-title`}
          >
            {antennas.map((antenna) => (
              <ColumnLink
                icon='list-ul'
                key={antenna.get('id')}
                iconComponent={AntennaIcon}
                activeIconComponent={AntennaIcon}
                text={antenna.get('title')}
                to={`/antennas/${antenna.get('id')}`}
                transparent
              />
            ))}
          </div>
        )}
      </div>
    </>
  );
};
