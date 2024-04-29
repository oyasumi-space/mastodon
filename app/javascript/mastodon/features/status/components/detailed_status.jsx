import PropTypes from 'prop-types';

import { injectIntl, defineMessages, FormattedDate, FormattedMessage } from 'react-intl';

import classNames from 'classnames';
import { Link } from 'react-router-dom';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';

import { AnimatedNumber } from 'mastodon/components/animated_number';
import EditedTimestamp from 'mastodon/components/edited_timestamp';
import { getHashtagBarForStatus } from 'mastodon/components/hashtag_bar';
import { Icon }  from 'mastodon/components/icon';
import PictureInPicturePlaceholder from 'mastodon/components/picture_in_picture_placeholder';
import { enableEmojiReaction } from 'mastodon/initial_state';

import { Avatar } from '../../../components/avatar';
import { DisplayName } from '../../../components/display_name';
import MediaGallery from '../../../components/media_gallery';
import StatusContent from '../../../components/status_content';
import StatusEmojiReactionsBar from '../../../components/status_emoji_reactions_bar';
import Audio from '../../audio';
import scheduleIdleTask from '../../ui/util/schedule_idle_task';
import Video from '../../video';

import Card from './card';

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
  searchability_public_short: { id: 'searchability.public.short', defaultMessage: 'Public' },
  searchability_private_short: { id: 'searchability.unlisted.short', defaultMessage: 'Followers' },
  searchability_direct_short: { id: 'searchability.private.short', defaultMessage: 'Reactionners' },
  searchability_limited_short: { id: 'searchability.direct.short', defaultMessage: 'Self only' },
});

class DetailedStatus extends ImmutablePureComponent {

  static contextTypes = {
    router: PropTypes.object,
  };

  static propTypes = {
    status: ImmutablePropTypes.map,
    onOpenMedia: PropTypes.func.isRequired,
    onOpenVideo: PropTypes.func.isRequired,
    onToggleHidden: PropTypes.func.isRequired,
    onTranslate: PropTypes.func.isRequired,
    measureHeight: PropTypes.bool,
    onHeightChange: PropTypes.func,
    domain: PropTypes.string.isRequired,
    compact: PropTypes.bool,
    showMedia: PropTypes.bool,
    pictureInPicture: ImmutablePropTypes.contains({
      inUse: PropTypes.bool,
      available: PropTypes.bool,
    }),
    onToggleMediaVisibility: PropTypes.func,
    onEmojiReact: PropTypes.func,
    onUnEmojiReact: PropTypes.func,
  };

  state = {
    height: null,
  };

  handleAccountClick = (e) => {
    if (e.button === 0 && !(e.ctrlKey || e.metaKey) && this.context.router) {
      e.preventDefault();
      this.context.router.history.push(`/@${this.props.status.getIn(['account', 'acct'])}`);
    }

    e.stopPropagation();
  };

  handleOpenVideo = (options) => {
    this.props.onOpenVideo(this.props.status.getIn(['media_attachments', 0]), options);
  };

  handleExpandedToggle = () => {
    this.props.onToggleHidden(this.props.status);
  };

  _measureHeight (heightJustChanged) {
    if (this.props.measureHeight && this.node) {
      scheduleIdleTask(() => this.node && this.setState({ height: Math.ceil(this.node.scrollHeight) + 1 }));

      if (this.props.onHeightChange && heightJustChanged) {
        this.props.onHeightChange();
      }
    }
  }

  setRef = c => {
    this.node = c;
    this._measureHeight();
  };

  componentDidUpdate (prevProps, prevState) {
    this._measureHeight(prevState.height !== this.state.height);
  }

  handleModalLink = e => {
    e.preventDefault();

    let href;

    if (e.target.nodeName !== 'A') {
      href = e.target.parentNode.href;
    } else {
      href = e.target.href;
    }

    window.open(href, 'mastodon-intent', 'width=445,height=600,resizable=no,menubar=no,status=no,scrollbars=yes');
  };

  handleTranslate = () => {
    const { onTranslate, status } = this.props;
    onTranslate(status);
  };

  _properStatus () {
    const { status } = this.props;

    if (status.get('reblog', null) !== null && typeof status.get('reblog') === 'object') {
      return status.get('reblog');
    } else {
      return status;
    }
  }

  getAttachmentAspectRatio () {
    const attachments = this._properStatus().get('media_attachments');

    if (attachments.getIn([0, 'type']) === 'video') {
      return `${attachments.getIn([0, 'meta', 'original', 'width'])} / ${attachments.getIn([0, 'meta', 'original', 'height'])}`;
    } else if (attachments.getIn([0, 'type']) === 'audio') {
      return '16 / 9';
    } else {
      return (attachments.size === 1 && attachments.getIn([0, 'meta', 'small', 'aspect'])) ? attachments.getIn([0, 'meta', 'small', 'aspect']) : '3 / 2'
    }
  }

  render () {
    const status = this._properStatus();
    const outerStyle = { boxSizing: 'border-box' };
    const { intl, compact, pictureInPicture } = this.props;

    if (!status) {
      return null;
    }

    let media           = '';
    let isCardMediaWithSensitive = false;
    let applicationLink = '';
    let reblogLink = '';
    let reblogIcon = 'retweet';
    let favouriteLink = '';
    let emojiReactionsLink = '';
    let statusReferencesLink = '';
    let edited = '';

    if (this.props.measureHeight) {
      outerStyle.height = `${this.state.height}px`;
    }

    const language = status.getIn(['translation', 'language']) || status.get('language');

    if (pictureInPicture.get('inUse')) {
      media = <PictureInPicturePlaceholder aspectRatio={this.getAttachmentAspectRatio()} />;
    } else if (status.get('media_attachments').size > 0) {
      if (status.getIn(['media_attachments', 0, 'type']) === 'audio') {
        const attachment = status.getIn(['media_attachments', 0]);
        const description = attachment.getIn(['translation', 'description']) || attachment.get('description');

        media = (
          <Audio
            src={attachment.get('url')}
            alt={description}
            lang={language}
            duration={attachment.getIn(['meta', 'original', 'duration'], 0)}
            poster={attachment.get('preview_url') || status.getIn(['account', 'avatar_static'])}
            backgroundColor={attachment.getIn(['meta', 'colors', 'background'])}
            foregroundColor={attachment.getIn(['meta', 'colors', 'foreground'])}
            accentColor={attachment.getIn(['meta', 'colors', 'accent'])}
            sensitive={status.get('sensitive')}
            visible={this.props.showMedia}
            blurhash={attachment.get('blurhash')}
            height={150}
            onToggleVisibility={this.props.onToggleMediaVisibility}
          />
        );
      } else if (status.getIn(['media_attachments', 0, 'type']) === 'video') {
        const attachment = status.getIn(['media_attachments', 0]);
        const description = attachment.getIn(['translation', 'description']) || attachment.get('description');

        media = (
          <Video
            preview={attachment.get('preview_url')}
            frameRate={attachment.getIn(['meta', 'original', 'frame_rate'])}
            aspectRatio={`${attachment.getIn(['meta', 'original', 'width'])} / ${attachment.getIn(['meta', 'original', 'height'])}`}
            blurhash={attachment.get('blurhash')}
            src={attachment.get('url')}
            alt={description}
            lang={language}
            width={300}
            height={150}
            onOpenVideo={this.handleOpenVideo}
            sensitive={status.get('sensitive')}
            visible={this.props.showMedia}
            onToggleVisibility={this.props.onToggleMediaVisibility}
          />
        );
      } else {
        media = (
          <MediaGallery
            standalone
            sensitive={status.get('sensitive')}
            media={status.get('media_attachments')}
            lang={language}
            height={300}
            onOpenMedia={this.props.onOpenMedia}
            visible={this.props.showMedia}
            onToggleVisibility={this.props.onToggleMediaVisibility}
          />
        );
      }
    } else if (status.get('card')) {
      media = <Card sensitive={status.get('sensitive') && !status.get('spoiler_text')} onOpenMedia={this.props.onOpenMedia} card={status.get('card', null)} />;
      isCardMediaWithSensitive = status.get('spoiler_text').length > 0;
    }

    let emojiReactionsBar = null;
    if (status.get('emoji_reactions')) {
      const emojiReactions = status.get('emoji_reactions');
      const emojiReactionPolicy = status.getIn(['account', 'other_settings', 'emoji_reaction_policy']) || 'allow';
      if (emojiReactions.size > 0 && enableEmojiReaction && emojiReactionPolicy !== 'block') {
        emojiReactionsBar = <StatusEmojiReactionsBar emojiReactions={emojiReactions} status={status} onEmojiReact={this.props.onEmojiReact} onUnEmojiReact={this.props.onUnEmojiReact} />;
      }
    }

    if (status.get('application')) {
      applicationLink = <> · <a className='detailed-status__application' href={status.getIn(['application', 'website'])} target='_blank' rel='noopener noreferrer'>{status.getIn(['application', 'name'])}</a></>;
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
    const visibilityLink = <> · <Icon id={visibilityIcon.icon} title={visibilityIcon.text} /></>;

    const searchabilityIconInfo = {
      'public': { icon: 'globe', text: intl.formatMessage(messages.searchability_public_short) },
      'private': { icon: 'unlock', text: intl.formatMessage(messages.searchability_private_short) },
      'direct': { icon: 'lock', text: intl.formatMessage(messages.searchability_direct_short) },
      'limited': { icon: 'at', text: intl.formatMessage(messages.searchability_limited_short) },
    };

    const searchabilityIcon = searchabilityIconInfo[status.get('searchability')];
    const searchabilityLink = <> · <Icon id={searchabilityIcon.icon} title={searchabilityIcon.text} /></>;

    if (['private', 'direct'].includes(status.get('visibility_ex'))) {
      reblogLink = '';
    } else if (this.context.router) {
      reblogLink = (
        <>
          {' · '}
          <Link to={`/@${status.getIn(['account', 'acct'])}/${status.get('id')}/reblogs`} className='detailed-status__link'>
            <Icon id={reblogIcon} />
            <span className='detailed-status__reblogs'>
              <AnimatedNumber value={status.get('reblogs_count')} />
            </span>
          </Link>
        </>
      );
    } else {
      reblogLink = (
        <>
          {' · '}
          <a href={`/interact/${status.get('id')}?type=reblog`} className='detailed-status__link' onClick={this.handleModalLink}>
            <Icon id={reblogIcon} />
            <span className='detailed-status__reblogs'>
              <AnimatedNumber value={status.get('reblogs_count')} />
            </span>
          </a>
        </>
      );
    }

    if (this.context.router) {
      favouriteLink = (
        <Link to={`/@${status.getIn(['account', 'acct'])}/${status.get('id')}/favourites`} className='detailed-status__link'>
          <Icon id='star' />
          <span className='detailed-status__favorites'>
            <AnimatedNumber value={status.get('favourites_count')} />
          </span>
        </Link>
      );
    } else {
      favouriteLink = (
        <a href={`/interact/${status.get('id')}?type=favourite`} className='detailed-status__link' onClick={this.handleModalLink}>
          <Icon id='star' />
          <span className='detailed-status__favorites'>
            <AnimatedNumber value={status.get('favourites_count')} />
          </span>
        </a>
      );
    }

    if (this.context.router) {
      emojiReactionsLink = (
        <Link to={`/@${status.getIn(['account', 'acct'])}/${status.get('id')}/emoji_reactions`} className='detailed-status__link'>
          <Icon id='smile-o' />
          <span className='detailed-status__favorites'>
            <AnimatedNumber value={status.get('emoji_reactions_count')} />
          </span>
        </Link>
      );
    } else {
      emojiReactionsLink = (
        <a href={`/interact/${status.get('id')}?type=emoji_reactions`} className='detailed-status__link' onClick={this.handleModalLink}>
          <Icon id='smile-o' />
          <span className='detailed-status__favorites'>
            <AnimatedNumber value={status.get('emoji_reactions_count')} />
          </span>
        </a>
      );
    }

    if (this.context.router) {
      statusReferencesLink = (
        <Link to={`/@${status.getIn(['account', 'acct'])}/${status.get('id')}/references`} className='detailed-status__link'>
          <Icon id='link' />
          <span className='detailed-status__favorites'>
            <AnimatedNumber value={status.get('status_referred_by_count')} />
          </span>
        </Link>
      );
    } else {
      statusReferencesLink = (
        <a href={`/interact/${status.get('id')}?type=references`} className='detailed-status__link' onClick={this.handleModalLink}>
          <Icon id='link' />
          <span className='detailed-status__favorites'>
            <AnimatedNumber value={status.get('status_referred_by_count')} />
          </span>
        </a>
      );
    }

    if (status.get('edited_at')) {
      edited = (
        <>
          {' · '}
          <EditedTimestamp statusId={status.get('id')} timestamp={status.get('edited_at')} />
        </>
      );
    }

    const {statusContentProps, hashtagBar} = getHashtagBarForStatus(status);
    const expanded = !status.get('hidden') || status.get('spoiler_text').length === 0;

    return (
      <div style={outerStyle}>
        <div ref={this.setRef} className={classNames('detailed-status', { compact })}>
          {status.get('visibility_ex') === 'direct' && (
            <div className='status__prepend'>
              <div className='status__prepend-icon-wrapper'><Icon id='at' className='status__prepend-icon' fixedWidth /></div>
              <FormattedMessage id='status.direct_indicator' defaultMessage='Private mention' />
            </div>
          )}
          <a href={`/@${status.getIn(['account', 'acct'])}`} onClick={this.handleAccountClick} className='detailed-status__display-name'>
            <div className='detailed-status__display-avatar'><Avatar account={status.get('account')} size={46} /></div>
            <DisplayName account={status.get('account')} localDomain={this.props.domain} />
          </a>

          <StatusContent
            status={status}
            expanded={!status.get('hidden')}
            onExpandedToggle={this.handleExpandedToggle}
            onTranslate={this.handleTranslate}
            {...statusContentProps}
          />

          {(!isCardMediaWithSensitive || !status.get('hidden')) && media}

          {(!status.get('spoiler_text') || expanded) && hashtagBar}

          {emojiReactionsBar}

          <div className='detailed-status__meta'>
            <a className='detailed-status__datetime' href={`/@${status.getIn(['account', 'acct'])}/${status.get('id')}`} target='_blank' rel='noopener noreferrer'>
              <FormattedDate value={new Date(status.get('created_at'))} hour12={false} year='numeric' month='short' day='2-digit' hour='2-digit' minute='2-digit' />
            </a>{edited}{visibilityLink}{searchabilityLink}{applicationLink}{reblogLink} · {favouriteLink} · {emojiReactionsLink} - {statusReferencesLink}
          </div>
        </div>
      </div>
    );
  }

}

export default injectIntl(DetailedStatus);
