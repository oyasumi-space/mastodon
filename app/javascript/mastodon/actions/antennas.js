import api from '../api';

export const ANTENNA_FETCH_REQUEST = 'ANTENNA_FETCH_REQUEST';
export const ANTENNA_FETCH_SUCCESS = 'ANTENNA_FETCH_SUCCESS';
export const ANTENNA_FETCH_FAIL    = 'ANTENNA_FETCH_FAIL';

export const ANTENNAS_FETCH_REQUEST = 'ANTENNAS_FETCH_REQUEST';
export const ANTENNAS_FETCH_SUCCESS = 'ANTENNAS_FETCH_SUCCESS';
export const ANTENNAS_FETCH_FAIL    = 'ANTENNAS_FETCH_FAIL';

export const ANTENNA_DELETE_REQUEST = 'ANTENNA_DELETE_REQUEST';
export const ANTENNA_DELETE_SUCCESS = 'ANTENNA_DELETE_SUCCESS';
export const ANTENNA_DELETE_FAIL    = 'ANTENNA_DELETE_FAIL';

export const fetchAntenna = id => (dispatch, getState) => {
  if (getState().getIn(['antennas', id])) {
    return;
  }

  dispatch(fetchAntennaRequest(id));

  api(getState).get(`/api/v1/antennas/${id}`)
    .then(({ data }) => dispatch(fetchAntennaSuccess(data)))
    .catch(err => dispatch(fetchAntennaFail(id, err)));
};

export const fetchAntennaRequest = id => ({
  type: ANTENNA_FETCH_REQUEST,
  id,
});

export const fetchAntennaSuccess = antenna => ({
  type: ANTENNA_FETCH_SUCCESS,
  antenna,
});

export const fetchAntennaFail = (id, error) => ({
  type: ANTENNA_FETCH_FAIL,
  id,
  error,
});

export const fetchAntennas = () => (dispatch, getState) => {
  dispatch(fetchAntennasRequest());

  api(getState).get('/api/v1/antennas')
    .then(({ data }) => dispatch(fetchAntennasSuccess(data)))
    .catch(err => dispatch(fetchAntennasFail(err)));
};

export const fetchAntennasRequest = () => ({
  type: ANTENNAS_FETCH_REQUEST,
});

export const fetchAntennasSuccess = antennas => ({
  type: ANTENNAS_FETCH_SUCCESS,
  antennas,
});

export const fetchAntennasFail = error => ({
  type: ANTENNAS_FETCH_FAIL,
  error,
});

export const deleteAntenna = id => (dispatch, getState) => {
  dispatch(deleteAntennaRequest(id));

  api(getState).delete(`/api/v1/antennas/${id}`)
    .then(() => dispatch(deleteAntennaSuccess(id)))
    .catch(err => dispatch(deleteAntennaFail(id, err)));
};

export const deleteAntennaRequest = id => ({
  type: ANTENNA_DELETE_REQUEST,
  id,
});

export const deleteAntennaSuccess = id => ({
  type: ANTENNA_DELETE_SUCCESS,
  id,
});

export const deleteAntennaFail = (id, error) => ({
  type: ANTENNA_DELETE_FAIL,
  id,
  error,
});
