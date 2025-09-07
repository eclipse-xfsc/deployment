import { createRemoteComponent, createRequires } from '@paciolan/remote-component';
import { resolve } from '../remote-component.config.js';
import { type DependencyTable } from '@paciolan/remote-component/dist/createRequires.js';

const requires = createRequires(resolve as unknown as () => DependencyTable);

export const RemoteComponent = createRemoteComponent({ requires });
