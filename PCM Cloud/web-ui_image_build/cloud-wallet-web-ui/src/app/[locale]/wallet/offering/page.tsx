'use client';

import AcceptDenyOfferingModal from '@/components/accept-offering-modal/AcceptOfferingModal';
import OfferingModal, { type OfferingLinkData } from '@/components/offering-modal/OfferingModal';
import Table, { type TableBody, type TableBodyMap, type TableData } from '@/components/table/Table';
import { genericFetch, useApiData } from '@/service/apiService';
import type { CredentialConfiguration, OfferingData } from '@/service/types';
import { AppContext } from '@/store/AppContextProvider';
import { getDetailedDisplay, getDisplayName } from '@/utils/objectUtils';
import { useKeycloak } from '@react-keycloak/web';
import { useQueryClient } from '@tanstack/react-query';
import { useLocale, useTranslations } from 'next-intl';
import { useContext, useEffect, useState } from 'react';
import { Button, Container } from 'react-bootstrap';
import { toast } from 'react-toastify';

function getFields(offering: CredentialConfiguration, locale: string): string {
  const { credentialSubject } = offering.credential_definition;

  if (!credentialSubject) return '';

  return Object.keys(credentialSubject)
    .map(subKey => getDisplayName(credentialSubject, subKey, locale))
    .join(', ');
}

const Offering = (): JSX.Element => {
  const { keycloak } = useKeycloak();
  const { setError } = useContext(AppContext);
  const t = useTranslations('Offering');
  const locale = useLocale();
  const queryClient = useQueryClient();

  const [tableData, setTableData] = useState<TableData>();
  const [rowData, setRowData] = useState<TableBodyMap>();
  const [showModal, setShowModal] = useState(false);
  const [showAcceptModal, setShowAcceptModal] = useState(false);
  const [isAccepting, setIsAccepting] = useState(false);
  const { data, isLoading } = useApiData<OfferingData[]>(
    'offeringList',
    `${process.env.API_URL_ACCOUNT_SERVICE}/credentials/offers/list`,
    { headers: { Authorization: `Bearer ${keycloak.token}` } }
  );

  useEffect(() => {
    if (!data || data.length <= 0) return;

    const tableBody = data.map(item => {
      const credentialTypes =
        item.offering.credential_configuration_ids ?? Object.keys(item.metadata.credential_configurations_supported);

      return credentialTypes.map(type => {
        if (!(type in item.metadata.credential_configurations_supported)) {
          return {
            logo: '',
            id: '',
            requestId: '',
            name: '',
            fields: '',
            status: '',
          };
        }

        const offering = item.metadata.credential_configurations_supported[type];

        return {
          logo: getDetailedDisplay(offering.display, locale).logo.url,
          id: item.requestId,
          requestId: item.requestId,
          name: getDetailedDisplay(offering.display, locale).name,
          fields: getFields(offering, locale),
          status: item.status,
        };
      });
    });

    setTableData({
      head: ['', 'id', 'requestId', 'name', 'fields', 'status'],
      body: tableBody.flat(2).filter(item => item.requestId && item.status),
    });
  }, [data, locale]);

  useEffect(() => {
    if (!rowData) return;

    const handleAction = async (value: TableBody, key: string): Promise<void> => {
      if (value.status !== 'received') {
        toast.error(t('offering-action-blocked'));
        return;
      }

      switch (key) {
        case 'accept':
          setShowAcceptModal(true);

          break;
        case 'deny':
          void handleDenyOffering(value);
          break;
      }
    };

    Promise.all([...rowData.entries()].map(([key, value]) => handleAction(value, key))).catch(error => setError(error));
  }, [rowData]);

  const handleDenyOffering = async (value: TableBody): Promise<void> => {
    await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/credentials/offers/${value?.requestId}/deny`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${keycloak.token}` },
      body: JSON.stringify({ keyId: '' }),
    })
      .then(() => {
        void queryClient.invalidateQueries({ queryKey: ['offeringList'] });
        toast.success(t('deny-success'));
      })
      .catch(setError);
  };

  const handleCreateOnSubmit = (data: OfferingLinkData): void => {
    const offerLink = async (): Promise<void> => {
      await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/credentials/offers/create`, {
        headers: { Authorization: `Bearer ${keycloak.token}` },
        body: JSON.stringify({ credential_offer: data.offeringLink }),
        method: 'PUT',
      });
    };

    offerLink()
      .then(() => {
        void queryClient.invalidateQueries({ queryKey: ['offeringList'] });
        toast.success(t('create-success'));
      })
      .catch(error => setError(error));
  };

  const handleAcceptDenyOnSubmit = (did: string): void => {
    const value = rowData?.get('accept');

    const acceptOffering = async (): Promise<void> => {
      setIsAccepting(true);

      await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/credentials/offers/${value?.requestId}/accept`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${keycloak.token}` },
        body: JSON.stringify({ keyId: did }),
      });
    };

    acceptOffering()
      .then(() => {
        void queryClient.invalidateQueries({ queryKey: ['offeringList'] });
        toast.success(t('accept-success'));
      })
      .catch(error => setError(error))
      .finally(() => setIsAccepting(false));
  };

  return (
    <>
      <Container fluid>
        <div className={`d-flex justify-content-between gap-2 mb-4`}>
          <h1 className="mb-0">{t('title')}</h1>

          <Button onClick={() => setShowModal(true)}>{t('add')}</Button>
        </div>

        <Table
          data={tableData}
          isLoading={isLoading || isAccepting}
          handleSelectRow={data => setRowData(data)}
          showActions
          filterActions={(data: TableBody) => data.status !== 'received'}
        >
          <Table.Actions>
            <Button
              variant="light"
              data-type="accept"
            >
              {t('accept')}
            </Button>

            <Button
              variant="light"
              data-type="deny"
            >
              {t('deny')}
            </Button>
          </Table.Actions>
        </Table>
      </Container>

      <OfferingModal
        show={showModal}
        handleClose={() => setShowModal(false)}
        onSubmit={handleCreateOnSubmit}
      />

      <AcceptDenyOfferingModal
        show={showAcceptModal}
        handleClose={() => setShowAcceptModal(false)}
        onSubmit={handleAcceptDenyOnSubmit}
      />
    </>
  );
};

export default Offering;
