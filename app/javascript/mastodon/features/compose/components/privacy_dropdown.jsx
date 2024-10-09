import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl, defineMessages } from 'react-intl';

import classNames from 'classnames';

import Overlay from 'react-overlays/Overlay';

import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import AlternateEmailIcon from '@/material-icons/400-24px/alternate_email.svg?react';
import BlockIcon from '@/material-icons/400-24px/block.svg?react';
import PublicUnlistedIcon from '@/material-icons/400-24px/cloud.svg?react';
import MutualIcon from '@/material-icons/400-24px/compare_arrows.svg?react';
import LoginIcon from '@/material-icons/400-24px/key.svg?react';
import LockIcon from '@/material-icons/400-24px/lock.svg?react';
import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import QuietTimeIcon from '@/material-icons/400-24px/quiet_time.svg?react';
import ReplyIcon from '@/material-icons/400-24px/reply.svg?react';
import LimitedIcon from '@/material-icons/400-24px/shield.svg?react';
import { DropdownSelector } from 'mastodon/components/dropdown_selector';
import { Icon }  from 'mastodon/components/icon';
import { enabledVisibilites } from 'mastodon/initial_state';

const messages = defineMessages({
  public_short: { id: 'privacy.public.short', defaultMessage: 'Public' },
  public_long: { id: 'privacy.public.long', defaultMessage: 'Anyone on and off Mastodon' },
  unlisted_short: { id: 'privacy.unlisted.short', defaultMessage: 'Quiet public' },
  unlisted_long: { id: 'privacy.unlisted.long', defaultMessage: 'Fewer algorithmic fanfares' },
  public_unlisted_short: { id: 'privacy.public_unlisted.short', defaultMessage: 'Local public' },
  public_unlisted_long: { id: 'privacy.public_unlisted.long', defaultMessage: 'Visible for all without GTL' },
  login_short: { id: 'privacy.login.short', defaultMessage: 'Login only' },
  login_long: { id: 'privacy.login.long', defaultMessage: 'Login user only' },
  private_short: { id: 'privacy.private.short', defaultMessage: 'Followers' },
  private_long: { id: 'privacy.private.long', defaultMessage: 'Only your followers' },
  limited_short: { id: 'privacy.limited.short', defaultMessage: 'Limited' },
  mutual_short: { id: 'privacy.mutual.short', defaultMessage: 'Mutual' },
  mutual_long: { id: 'privacy.mutual.long', defaultMessage: 'Mutual follows only' },
  circle_short: { id: 'privacy.circle.short', defaultMessage: 'Circle' },
  circle_long: { id: 'privacy.circle.long', defaultMessage: 'Circle members only' },
  reply_short: { id: 'privacy.reply.short', defaultMessage: 'Reply' },
  reply_long: { id: 'privacy.reply.long', defaultMessage: 'Reply to limited post' },
  direct_short: { id: 'privacy.direct.short', defaultMessage: 'Specific people' },
  direct_long: { id: 'privacy.direct.long', defaultMessage: 'Everyone mentioned in the post' },
  banned_short: { id: 'privacy.banned.short', defaultMessage: 'No posting' },
  banned_long: { id: 'privacy.banned.long', defaultMessage: 'All public range submissions are disabled. User settings need to be modified.' },
  change_privacy: { id: 'privacy.change', defaultMessage: 'Change post privacy' },
  unlisted_extra: { id: 'privacy.unlisted.additional', defaultMessage: 'This behaves exactly like public, except the post will not appear in live feeds or hashtags, explore, or Mastodon search, even if you are opted-in account-wide.' },
});

class PrivacyDropdown extends PureComponent {

  static propTypes = {
    isUserTouching: PropTypes.func,
    onModalOpen: PropTypes.func,
    onModalClose: PropTypes.func,
    value: PropTypes.string.isRequired,
    onChange: PropTypes.func.isRequired,
    noDirect: PropTypes.bool,
    noLimited: PropTypes.bool,
    replyToLimited: PropTypes.bool,
    container: PropTypes.func,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
  };

  state = {
    open: false,
    placement: 'bottom',
  };

  handleToggle = () => {
    if (this.props.isUserTouching && this.props.isUserTouching()) {
      if (this.state.open) {
        this.props.onModalClose();
      } else {
        this.props.onModalOpen({
          actions: this.options.map(option => ({ ...option, active: option.value === this.props.value })),
          onClick: this.handleModalActionClick,
        });
      }
    } else {
      if (this.state.open && this.activeElement) {
        this.activeElement.focus({ preventScroll: true });
      }
      this.setState({ open: !this.state.open });
    }
  };

  handleModalActionClick = (e) => {
    e.preventDefault();

    const { value } = this.options[e.currentTarget.getAttribute('data-index')];

    this.props.onModalClose();
    this.props.onChange(value);
  };

  handleKeyDown = e => {
    switch(e.key) {
    case 'Escape':
      this.handleClose();
      break;
    }
  };

  handleMouseDown = () => {
    if (!this.state.open) {
      this.activeElement = document.activeElement;
    }
  };

  handleButtonKeyDown = (e) => {
    switch(e.key) {
    case ' ':
    case 'Enter':
      this.handleMouseDown();
      break;
    }
  };

  handleClose = () => {
    if (this.state.open && this.activeElement) {
      this.activeElement.focus({ preventScroll: true });
    }
    this.setState({ open: false });
  };

  handleChange = value => {
    this.props.onChange(value);
  };

  UNSAFE_componentWillMount () {
    const { intl: { formatMessage } } = this.props;

    this.dynamicOptions = [
      { icon: 'reply', iconComponent: ReplyIcon, value: 'reply', text: formatMessage(messages.reply_short), meta: formatMessage(messages.reply_long), extra: formatMessage(messages.limited_short), extraIconComponent: LimitedIcon },
      { icon: 'ban', iconComponent: BlockIcon, value: 'banned', text: formatMessage(messages.banned_short), meta: formatMessage(messages.banned_long) },
    ];

    this.originalOptions = [
      { icon: 'globe', iconComponent: PublicIcon, value: 'public', text: formatMessage(messages.public_short), meta: formatMessage(messages.public_long) },
      { icon: 'cloud', iconComponent: PublicUnlistedIcon, value: 'public_unlisted', text: formatMessage(messages.public_unlisted_short), meta: formatMessage(messages.public_unlisted_long) },
      { icon: 'key', iconComponent: LoginIcon, value: 'login', text: formatMessage(messages.login_short), meta: formatMessage(messages.login_long) },
      { icon: 'unlock', iconComponent: QuietTimeIcon,  value: 'unlisted', text: formatMessage(messages.unlisted_short), meta: formatMessage(messages.unlisted_long), extra: formatMessage(messages.unlisted_extra) },
      { icon: 'lock', iconComponent: LockIcon, value: 'private', text: formatMessage(messages.private_short), meta: formatMessage(messages.private_long) },
      { icon: 'exchange', iconComponent: MutualIcon, value: 'mutual', text: formatMessage(messages.mutual_short), meta: formatMessage(messages.mutual_long), extra: formatMessage(messages.limited_short), extraIconComponent: LimitedIcon },
      { icon: 'user-circle', iconComponent: CircleIcon, value: 'circle', text: formatMessage(messages.circle_short), meta: formatMessage(messages.circle_long), extra: formatMessage(messages.limited_short), extraIconComponent: LimitedIcon },
      { icon: 'at', iconComponent: AlternateEmailIcon, value: 'direct', text: formatMessage(messages.direct_short), meta: formatMessage(messages.direct_long) },
      ...this.dynamicOptions,
    ];

    this.options = [...this.originalOptions];

    if (this.props.noDirect) {
      this.options = this.options.filter((opt) => opt.value !== 'direct');
    }

    if (this.props.noLimited) {
      this.options = this.options.filter((opt) => !['mutual', 'circle'].includes(opt.value));
    }

    if (enabledVisibilites) {
      this.options = this.options.filter((opt) => enabledVisibilites.includes(opt.value));
    }

    if (this.options.length === 0) {
      this.options.push(this.dynamicOptions.find((opt) => opt.value === 'banned'));
      this.props.onChange('banned');
    }
  }

  setTargetRef = c => {
    this.target = c;
  };

  findTarget = () => {
    return this.target;
  };

  handleOverlayEnter = (state) => {
    this.setState({ placement: state.placement });
  };

  render () {
    const { value, container, disabled, intl, replyToLimited } = this.props;
    const { open, placement } = this.state;

    if (replyToLimited) {
      if (!this.options.some((op) => op.value === 'reply')) {
        this.options.unshift(this.dynamicOptions.find((opt) => opt.value === 'reply'));
      }
    } else {
      if (this.options.some((op) => op.value === 'reply')) {
        this.options = this.options.filter((op) => op.value !== 'reply');
      }
    }

    const valueOption = (disabled ? this.originalOptions : this.options).find(item => item.value === value) || this.options[0];

    return (
      <div ref={this.setTargetRef} onKeyDown={this.handleKeyDown}>
        <button
          type='button'
          title={intl.formatMessage(messages.change_privacy)}
          aria-expanded={open}
          onClick={this.handleToggle}
          onMouseDown={this.handleMouseDown}
          onKeyDown={this.handleButtonKeyDown}
          disabled={disabled}
          className={classNames('dropdown-button', { active: open })}
        >
          <Icon id={valueOption.icon} icon={valueOption.iconComponent} />
          <span className='dropdown-button__label'>{valueOption.text}</span>
        </button>

        <Overlay show={open} offset={[5, 5]} placement={placement} flip target={this.findTarget} container={container} popperConfig={{ strategy: 'fixed', onFirstUpdate: this.handleOverlayEnter }}>
          {({ props, placement }) => (
            <div {...props}>
              <div className={`dropdown-animation privacy-dropdown__dropdown ${placement}`}>
                <DropdownSelector
                  items={this.options}
                  value={value}
                  onClose={this.handleClose}
                  onChange={this.handleChange}
                />
              </div>
            </div>
          )}
        </Overlay>
      </div>
    );
  }

}

export default injectIntl(PrivacyDropdown);
