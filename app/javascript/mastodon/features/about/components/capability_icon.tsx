import type { FC } from 'react';

import type { IntlShape } from 'react-intl';
import { defineMessages } from 'react-intl';

import { Icon } from '@/mastodon/components/icon';
import DisabledIcon from '@/material-icons/400-24px/close-fill.svg?react';
import EnabledIcon from '@/material-icons/400-24px/done-fill.svg?react';

const messages = defineMessages({
  enabled: { id: 'about.enabled', defaultMessage: 'Enabled' },
  disabled: { id: 'about.disabled', defaultMessage: 'Disabled' },
});

interface CapabilityIconProps {
  intl: IntlShape;
  state: boolean;
}

export const CapabilityIcon: FC<CapabilityIconProps> = ({ intl, state }) => {
  if (state) {
    return (
      <span className='capability-icon enabled'>
        <Icon
          id='check'
          icon={EnabledIcon}
          aria-label={intl.formatMessage(messages.enabled)}
        />
        {intl.formatMessage(messages.enabled)}
      </span>
    );
  } else {
    return (
      <span className='capability-icon disabled'>
        <Icon
          id='times'
          icon={DisabledIcon}
          aria-label={intl.formatMessage(messages.disabled)}
        />
        {intl.formatMessage(messages.disabled)}
      </span>
    );
  }
};
