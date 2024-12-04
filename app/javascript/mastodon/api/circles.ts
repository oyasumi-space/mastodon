import {
  apiRequestPost,
  apiRequestPut,
  apiRequestGet,
  apiRequestDelete,
} from 'mastodon/api';
import type { ApiAccountJSON } from 'mastodon/api_types/accounts';
import type { ApiCircleJSON } from 'mastodon/api_types/circles';

export const apiCreate = (circle: Partial<ApiCircleJSON>) =>
  apiRequestPost<ApiCircleJSON>('v1/circles', circle);

export const apiUpdate = (circle: Partial<ApiCircleJSON>) =>
  apiRequestPut<ApiCircleJSON>(`v1/circles/${circle.id}`, circle);

export const apiGetAccounts = (circleId: string) =>
  apiRequestGet<ApiAccountJSON[]>(`v1/circles/${circleId}/accounts`, {
    limit: 0,
  });

export const apiGetAccountCircles = (accountId: string) =>
  apiRequestGet<ApiCircleJSON[]>(`v1/accounts/${accountId}/circles`);

export const apiAddAccountToCircle = (circleId: string, accountId: string) =>
  apiRequestPost(`v1/circles/${circleId}/accounts`, {
    account_ids: [accountId],
  });

export const apiRemoveAccountFromCircle = (
  circleId: string,
  accountId: string,
) =>
  apiRequestDelete(`v1/circles/${circleId}/accounts`, {
    account_ids: [accountId],
  });
