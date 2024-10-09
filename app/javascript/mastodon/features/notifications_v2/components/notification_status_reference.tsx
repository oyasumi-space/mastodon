import { FormattedMessage } from 'react-intl';

import ReferenceIcon from '@/material-icons/400-24px/link.svg?react';
import type { NotificationGroupStatusReference } from 'mastodon/models/notification_group';

import type { LabelRenderer } from './notification_group_with_status';
import { NotificationWithStatus } from './notification_with_status';

const labelRenderer: LabelRenderer = (displayedName) => (
  <FormattedMessage
    id='notification.status_reference'
    defaultMessage='{name} quoted your post'
    values={{ name: displayedName }}
  />
);

export const NotificationStatusReference: React.FC<{
  notification: NotificationGroupStatusReference;
  unread: boolean;
}> = ({ notification, unread }) => {
  return (
    <NotificationWithStatus
      type='status_reference'
      icon={ReferenceIcon}
      iconId='reply'
      accountIds={notification.sampleAccountIds}
      count={notification.notifications_count}
      statusId={notification.statusId}
      labelRenderer={labelRenderer}
      unread={unread}
      muted
    />
  );
};
