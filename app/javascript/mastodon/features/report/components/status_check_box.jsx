import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl, defineMessages } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';

import { Avatar } from 'mastodon/components/avatar';
import { DisplayName } from 'mastodon/components/display_name';
import { Icon }  from 'mastodon/components/icon';
import MediaAttachments from 'mastodon/components/media_attachments';
import { RelativeTimestamp } from 'mastodon/components/relative_timestamp';
import StatusContent from 'mastodon/components/status_content';

import Option from './option';

const messages = defineMessages({
  public_short: { id: 'privacy.public.short', defaultMessage: 'Public' },
  unlisted_short: { id: 'privacy.unlisted.short', defaultMessage: 'Unlisted' },
  public_unlisted_short: { id: 'privacy.public_unlisted.short', defaultMessage: 'Public unlisted' },
  login_short: { id: 'privacy.login.short', defaultMessage: 'Login only' },
  private_short: { id: 'privacy.private.short', defaultMessage: 'Followers only' },
  limited_short: { id: 'privacy.limited.short', defaultMessage: 'Limited menbers only' },
  mutual_short: { id: 'privacy.mutual.short', defaultMessage: 'Mutual followers only' },
  circle_short: { id: 'privacy.circle.short', defaultMessage: 'Circle members only' },
  direct_short: { id: 'privacy.direct.short', defaultMessage: 'Mentioned people only' },
});

class StatusCheckBox extends PureComponent {

  static propTypes = {
    id: PropTypes.string.isRequired,
    status: ImmutablePropTypes.map.isRequired,
    checked: PropTypes.bool,
    onToggle: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  handleStatusesToggle = (value, checked) => {
    const { onToggle } = this.props;
    onToggle(value, checked);
  };

  render () {
    const { status, checked, intl } = this.props;

    if (status.get('reblog')) {
      return null;
    }

    const visibilityIconInfo = {
      'public': { icon: 'globe', text: intl.formatMessage(messages.public_short) },
      'unlisted': { icon: 'unlock', text: intl.formatMessage(messages.unlisted_short) },
      'public_unlisted': { icon: 'cloud', text: intl.formatMessage(messages.public_unlisted_short) },
      'login': { icon: 'key', text: intl.formatMessage(messages.login_short) },
      'private': { icon: 'lock', text: intl.formatMessage(messages.private_short) },
      'limited': { icon: 'get-pocket', text: intl.formatMessage(messages.limited_short) },
      'mutual': { icon: 'exchange', text: intl.formatMessage(messages.mutual_short) },
      'circle': { icon: 'user-circle', text: intl.formatMessage(messages.circle_short) },
      'direct': { icon: 'at', text: intl.formatMessage(messages.direct_short) },
    };

    const visibilityIcon = visibilityIconInfo[status.get('limited_scope') || status.get('visibility_ex')];

    const labelComponent = (
      <div className='status-check-box__status poll__option__text'>
        <div className='detailed-status__display-name'>
          <div className='detailed-status__display-avatar'>
            <Avatar account={status.get('account')} size={46} />
          </div>

          <div>
            <DisplayName account={status.get('account')} /> · <span className='status__visibility-icon'><Icon id={visibilityIcon.icon} title={visibilityIcon.text} /></span> <RelativeTimestamp timestamp={status.get('created_at')} />
          </div>
        </div>

        <StatusContent status={status} />
        <MediaAttachments status={status} />
      </div>
    );

    return (
      <Option
        name='status_ids'
        value={status.get('id')}
        checked={checked}
        onToggle={this.handleStatusesToggle}
        label={status.get('search_index')}
        labelComponent={labelComponent}
        multiple
      />
    );
  }

}

export default injectIntl(StatusCheckBox);
