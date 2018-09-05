import * as _ from 'lodash';

import * as packageJson from '../../package.json';
let version = (packageJson as any).version;
const tagExtra = process.env.SUPERVISOR_TAG_EXTRA;
if (!_.isEmpty(tagExtra)) {
	version += '+' + tagExtra;
}
export = version;