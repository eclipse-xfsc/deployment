'use client';

import { RemoteComponent } from '@/RemoteComponent';
import LoadingSpinner from '@/components/loading-spinner/LoadingSpinner';
import { type Plugin as IPlugin } from '@/components/side-menu/WalletSideMenu';
import { AppContext } from '@/store/AppContextProvider';
import { useKeycloak } from '@react-keycloak/web';
import { useQueryClient } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { useContext, useEffect, useState } from 'react';
import { type PluginWrapper } from '../../plugin-overview/page';

interface PluginProps {
  params: {
    plugin: string;
  };
}

const Plugin = ({ params }: PluginProps): JSX.Element => {
  const [PluginComponent, setPluginComponent] = useState<JSX.Element>();
  const pluginDiscoveryData = useQueryClient().getQueryData<PluginWrapper>(['pluginDiscovery']);
  const t = useTranslations('Plugin');
  const { setError } = useContext(AppContext);
  const { keycloak } = useKeycloak();
  const [pluginMetadata, setPluginMetadata] = useState<Record<string, string>>({});

  useEffect(() => {
    const params = JSON.parse(localStorage.getItem('pluginParams') as string);

    if (params) setPluginMetadata(params);

    return () => {
      localStorage.removeItem('pluginParams');
    };
  }, []);

  const fetchPluginData = (pluginDiscovery: IPlugin[], pluginRoute: string, metadata: Record<string, string>): void => {
    const foundPlugin = pluginDiscovery.find(plugin => plugin.route === pluginRoute);

    const url = `${process.env.API_URL}/dynamic/plugins${foundPlugin?.url}/main.js`;

    setPluginComponent(
      <RemoteComponent
        url={url}
        fallback={<LoadingSpinner />}
        render={({ err, Component }) =>
          err ? (
            <div>{err.toString()}</div>
          ) : (
            <Component
              token={keycloak.token}
              metadata={metadata}
              error={(error: Error) => setError(error)}
            />
          )
        }
      />
    );
  };

  useEffect(() => {
    if (!pluginDiscoveryData) {
      setPluginComponent(<div>{t('not-found')}</div>);
    } else {
      fetchPluginData(pluginDiscoveryData.plugins, params.plugin, pluginMetadata);
    }
  }, [pluginDiscoveryData, params.plugin, pluginMetadata]);

  return <div className="min-vh-100">{PluginComponent}</div>;
};

export default Plugin;
