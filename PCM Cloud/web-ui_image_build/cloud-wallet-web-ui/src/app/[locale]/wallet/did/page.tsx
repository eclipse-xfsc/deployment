'use client';

import { Button, Container } from 'react-bootstrap';
import Table, { type TableData } from '@/components/table/Table';
import type { DidData } from '@/service/types';
import { genericFetch, useApiData } from '@/service/apiService';
import { useContext, useEffect, useState } from 'react';
import { AppContext } from '@/store/AppContextProvider';
import { formatDateString } from '@/utils/dateUtils';
import { useTranslations } from 'next-intl';
import CreateDidModal from '@/components/create-did-modal/CreateDidModal';
import { toast } from 'react-toastify';
import { useKeycloak } from '@react-keycloak/web';
import { useQueryClient } from '@tanstack/react-query';

const Did = (): JSX.Element => {
  const { keycloak } = useKeycloak();
  const t = useTranslations('Did');
  const { setError } = useContext(AppContext);
  const [tableData, setTableData] = useState<TableData>();
  const [showModal, setShowModal] = useState(false);
  const queryClient = useQueryClient();
  const { data, isLoading } = useApiData<DidData>('didList', `${process.env.API_URL_ACCOUNT_SERVICE}/kms/did/list`, {
    headers: { Authorization: `Bearer ${keycloak.token}` },
  });

  useEffect(() => {
    if (!data?.list.length) return;

    setTableData({
      head: ['id', 'did', 'timestamp'],
      body: data.list.map(({ ...did }) => {
        return {
          ...did,
          timestamp: formatDateString(did.timestamp),
        };
      }),
    });
  }, [data]);

  const handleCreateDidOnSubmit = (keyType: string): void => {
    const createDid = async (): Promise<void> => {
      await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/kms/did/create`, {
        headers: { Authorization: `Bearer ${keycloak.token}` },
        body: JSON.stringify({ keyType }),
        method: 'POST',
      });
    };

    createDid()
      .then(() => {
        void queryClient.invalidateQueries({ queryKey: ['didList'] });
        toast.success(t('create-success'));
      })
      .catch(error => setError(error));
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
          isLoading={isLoading}
          showId
        ></Table>
      </Container>

      <CreateDidModal
        show={showModal}
        handleClose={() => setShowModal(false)}
        onSubmit={handleCreateDidOnSubmit}
      />
    </>
  );
};

export default Did;
