import type { RecordOf } from 'immutable';
import { Record } from 'immutable';

import type { ApiCircleJSON } from 'mastodon/api_types/circles';

type CircleShape = Required<ApiCircleJSON>; // no changes from server shape
export type Circle = RecordOf<CircleShape>;

const CircleFactory = Record<CircleShape>({
  id: '',
  title: '',
});

export function createCircle(attributes: Partial<CircleShape>) {
  return CircleFactory(attributes);
}
