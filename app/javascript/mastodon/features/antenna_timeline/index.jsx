import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { FormattedMessage, defineMessages, injectIntl } from 'react-intl';

import { Helmet } from 'react-helmet';

import ImmutablePropTypes from 'react-immutable-proptypes';
import { connect } from 'react-redux';

import { fetchAntenna, deleteAntenna } from 'mastodon/actions/antennas';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import { openModal } from 'mastodon/actions/modal';
import { connectAntennaStream } from 'mastodon/actions/streaming';
import { expandAntennaTimeline } from 'mastodon/actions/timelines';
import Column from 'mastodon/components/column';
import ColumnHeader from 'mastodon/components/column_header';
import { Icon }  from 'mastodon/components/icon';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import BundleColumnError from 'mastodon/features/ui/components/bundle_column_error';
import StatusListContainer from 'mastodon/features/ui/containers/status_list_container';

const messages = defineMessages({
  deleteMessage: { id: 'confirmations.delete_antenna.message', defaultMessage: 'Are you sure you want to permanently delete this antenna?' },
  deleteConfirm: { id: 'confirmations.delete_antenna.confirm', defaultMessage: 'Delete' },
});

const mapStateToProps = (state, props) => ({
  antenna: state.getIn(['antennas', props.params.id]),
  hasUnread: state.getIn(['timelines', `antenna:${props.params.id}`, 'unread']) > 0,
});

class AntennaTimeline extends PureComponent {

  static contextTypes = {
    router: PropTypes.object,
  };

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    columnId: PropTypes.string,
    hasUnread: PropTypes.bool,
    multiColumn: PropTypes.bool,
    antenna: PropTypes.oneOfType([ImmutablePropTypes.map, PropTypes.bool]),
    intl: PropTypes.object.isRequired,
  };

  handlePin = () => {
    const { columnId, dispatch } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('ANTENNA_TIMELINE', { id: this.props.params.id }));
      this.context.router.history.push('/');
    }
  };

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  };

  handleHeaderClick = () => {
    this.column.scrollTop();
  };

  componentDidMount () {
    const { dispatch } = this.props;
    const { id } = this.props.params;

    dispatch(fetchAntenna(id));
    dispatch(expandAntennaTimeline(id));

    this.disconnect = dispatch(connectAntennaStream(id));
  }

  UNSAFE_componentWillReceiveProps (nextProps) {
    const { dispatch } = this.props;
    const { id } = nextProps.params;

    if (id !== this.props.params.id) {
      if (this.disconnect) {
        this.disconnect();
        this.disconnect = null;
      }

      dispatch(fetchAntenna(id));
      dispatch(expandAntennaTimeline(id));

      this.disconnect = dispatch(connectAntennaStream(id));
    }
  }

  componentWillUnmount () {
    if (this.disconnect) {
      this.disconnect();
      this.disconnect = null;
    }
  }

  setRef = c => {
    this.column = c;
  };

  handleLoadMore = maxId => {
    const { id } = this.props.params;
    this.props.dispatch(expandAntennaTimeline(id, { maxId }));
  };

  handleEditClick = () => {
    this.context.router.history.push(`/antennasw/${this.props.params.id}`);
  };

  handleDeleteClick = () => {
    const { dispatch, columnId, intl } = this.props;
    const { id } = this.props.params;

    dispatch(openModal({
      modalType: 'CONFIRM',
      modalProps: {
        message: intl.formatMessage(messages.deleteMessage),
        confirm: intl.formatMessage(messages.deleteConfirm),
        onConfirm: () => {
          dispatch(deleteAntenna(id));

          if (columnId) {
            dispatch(removeColumn(columnId));
          } else {
            this.context.router.history.push('/antennasw');
          }
        },
      },
    }));
  };

  render () {
    const { hasUnread, columnId, multiColumn, antenna } = this.props;
    const { id } = this.props.params;
    const pinned = !!columnId;
    const title  = antenna ? antenna.get('title') : id;

    if (typeof antenna === 'undefined') {
      return (
        <Column>
          <div className='scrollable'>
            <LoadingIndicator />
          </div>
        </Column>
      );
    } else if (antenna === false) {
      return (
        <BundleColumnError multiColumn={multiColumn} errorType='routing' />
      );
    }

    return (
      <Column bindToDocument={!multiColumn} ref={this.setRef} label={title}>
        <ColumnHeader
          icon='wifi'
          active={hasUnread}
          title={title}
          onPin={this.handlePin}
          onMove={this.handleMove}
          onClick={this.handleHeaderClick}
          pinned={pinned}
          multiColumn={multiColumn}
        >
          <div className='column-settings__row column-header__links'>
            <button type='button' className='text-btn column-header__setting-btn' tabIndex={0} onClick={this.handleEditClick}>
              <Icon id='pencil' /> <FormattedMessage id='antennas.edit' defaultMessage='Edit antenna' />
            </button>

            <button type='button' className='text-btn column-header__setting-btn' tabIndex={0} onClick={this.handleDeleteClick}>
              <Icon id='trash' /> <FormattedMessage id='antennas.delete' defaultMessage='Delete antenna' />
            </button>
          </div>
        </ColumnHeader>

        <StatusListContainer
          trackScroll={!pinned}
          scrollKey={`antenna_timeline-${columnId}`}
          timelineId={`antenna:${id}`}
          onLoadMore={this.handleLoadMore}
          emptyMessage={<FormattedMessage id='empty_column.antenna' defaultMessage='There is nothing in this antenna yet. When members of this list post new statuses, they will appear here.' />}
          bindToDocument={!multiColumn}
        />

        <Helmet>
          <title>{title}</title>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(injectIntl(AntennaTimeline));
