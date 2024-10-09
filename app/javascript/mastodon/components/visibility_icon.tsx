import { defineMessages, useIntl } from 'react-intl';

import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import AlternateEmailIcon from '@/material-icons/400-24px/alternate_email.svg?react';
import PublicUnlistedIcon from '@/material-icons/400-24px/cloud.svg?react';
import MutualIcon from '@/material-icons/400-24px/compare_arrows.svg?react';
import LoginIcon from '@/material-icons/400-24px/key.svg?react';
import LockIcon from '@/material-icons/400-24px/lock.svg?react';
import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import QuietTimeIcon from '@/material-icons/400-24px/quiet_time.svg?react';
import ReplyIcon from '@/material-icons/400-24px/reply.svg?react';
import LimitedIcon from '@/material-icons/400-24px/shield.svg?react';
import PersonalIcon from '@/material-icons/400-24px/sticky_note.svg?react';
import type { StatusVisibility } from 'mastodon/models/status';

import { Icon } from './icon';

const messages = defineMessages({
  public_short: { id: 'privacy.public.short', defaultMessage: 'Public' },
  public_unlisted_short: {
    id: 'privacy.public_unlisted.short',
    defaultMessage: 'Local public',
  },
  login_short: {
    id: 'privacy.login.short',
    defaultMessage: 'Login only',
  },
  unlisted_short: {
    id: 'privacy.unlisted.short',
    defaultMessage: 'Quiet public',
  },
  private_short: {
    id: 'privacy.private.short',
    defaultMessage: 'Followers',
  },
  limited_short: {
    id: 'privacy.limited.short',
    defaultMessage: 'Limited',
  },
  mutual_short: {
    id: 'privacy.mutual.short',
    defaultMessage: 'Mutual',
  },
  circle_short: {
    id: 'privacy.circle.short',
    defaultMessage: 'Circle',
  },
  reply_short: {
    id: 'privacy.reply.short',
    defaultMessage: 'Reply',
  },
  personal_short: {
    id: 'privacy.personal.short',
    defaultMessage: 'Yourself only',
  },
  direct_short: {
    id: 'privacy.direct.short',
    defaultMessage: 'Specific people',
  },
});

export const VisibilityIcon: React.FC<{ visibility: StatusVisibility }> = ({
  visibility,
}) => {
  const intl = useIntl();

  const visibilityIconInfo = {
    public: {
      icon: 'globe',
      iconComponent: PublicIcon,
      text: intl.formatMessage(messages.public_short),
    },
    public_unlisted: {
      icon: 'cloud',
      iconComponent: PublicUnlistedIcon,
      text: intl.formatMessage(messages.public_unlisted_short),
    },
    login: {
      icon: 'key',
      iconComponent: LoginIcon,
      text: intl.formatMessage(messages.login_short),
    },
    unlisted: {
      icon: 'unlock',
      iconComponent: QuietTimeIcon,
      text: intl.formatMessage(messages.unlisted_short),
    },
    private: {
      icon: 'lock',
      iconComponent: LockIcon,
      text: intl.formatMessage(messages.private_short),
    },
    limited: {
      icon: 'get-pocket',
      iconComponent: LimitedIcon,
      text: intl.formatMessage(messages.limited_short),
    },
    mutual: {
      icon: 'exchange',
      iconComponent: MutualIcon,
      text: intl.formatMessage(messages.mutual_short),
    },
    circle: {
      icon: 'user-circle',
      iconComponent: CircleIcon,
      text: intl.formatMessage(messages.circle_short),
    },
    reply: {
      icon: 'reply',
      iconComponent: ReplyIcon,
      text: intl.formatMessage(messages.reply_short),
    },
    personal: {
      icon: 'sticky-note-o',
      iconComponent: PersonalIcon,
      text: intl.formatMessage(messages.personal_short),
    },
    direct: {
      icon: 'at',
      iconComponent: AlternateEmailIcon,
      text: intl.formatMessage(messages.direct_short),
    },
  };

  const visibilityIcon = visibilityIconInfo[visibility];

  return (
    <Icon
      id={visibilityIcon.icon}
      icon={visibilityIcon.iconComponent}
      title={visibilityIcon.text}
    />
  );
};
