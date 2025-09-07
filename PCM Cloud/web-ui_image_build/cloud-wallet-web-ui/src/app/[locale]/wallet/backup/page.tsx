'use client';

import { Button, Container } from 'react-bootstrap';
import Table, { type TableBody, type TableBodyMap, type TableData } from '@/components/table/Table';
import { useContext, useEffect, useState } from 'react';
import { AppContext } from '@/store/AppContextProvider';
import { genericFetch, useApiData } from '@/service/apiService';
import type { BackupList, BackupQrCodeData } from '@/service/types';
import { useTranslations } from 'next-intl';
import QrModal from '@/components/qr-modal/QrModal';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faTrash } from '@fortawesome/free-solid-svg-icons';
import { toast } from 'react-toastify';
import AddBackupModal from '@/components/add-backup-modal/AddBackupModal';
import { useKeycloak } from '@react-keycloak/web';
import { useQueryClient } from '@tanstack/react-query';

interface QrCodeModalProps {
  qrCode: string;
  title: string;
}

const Backup = (): JSX.Element => {
  const { keycloak } = useKeycloak();
  const { setError } = useContext(AppContext);
  const t = useTranslations('Backup');
  const queryClient = useQueryClient();

  const [tableData, setTableData] = useState<TableData>();
  const [rowData, setRowData] = useState<TableBodyMap>();
  const [showQrModal, setShowQrModal] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  const [qrData, setQrData] = useState<QrCodeModalProps>();
  const { data, isLoading } = useApiData<BackupList>(
    'backupList',
    `${process.env.API_URL_ACCOUNT_SERVICE}/credentials/backup/all`,
    { headers: { Authorization: `Bearer ${keycloak.token}` } }
  );

  useEffect(() => {
    if (!data || data.backups.length <= 0) return;

    const backupData = data.backups;

    setTableData({
      head: ['bindingId', 'name', 'user_id'],
      body: backupData
        .filter(backup => backup.bindingId)
        .map(({ ...backup }, i) => {
          return {
            id: backup.bindingId ?? i,
            bindingId: backup.bindingId,
            name: backup.name,
            user_id: backup.user_id,
          };
        }),
    });
  }, [data]);

  useEffect(() => {
    if (!rowData) return;

    const handleAction = async (value: TableBody, key: string): Promise<void> => {
      switch (key) {
        case 'download':
          setQrData({
            qrCode: await genericFetch<BackupQrCodeData>(
              `${process.env.API_URL_ACCOUNT_SERVICE}/credentials/backup/link/download?bindingId=${value.bindingId}`,
              {
                headers: {
                  Authorization: `Bearer ${keycloak.token}`,
                },
              }
            ).then(data => data.path),
            title: t('download'),
          });
          setShowQrModal(true);

          break;
        case 'delete':
          await genericFetch<BackupQrCodeData>(
            `${process.env.API_URL_ACCOUNT_SERVICE}/credentials/backup/${value.bindingId}`,
            {
              headers: { Authorization: `Bearer ${keycloak.token}` },
              method: 'DELETE',
            }
          ).then(() => {
            toast.success(t('delete-success'));
            void queryClient.invalidateQueries({ queryKey: ['backupList'] });
          });

          break;
      }
    };

    rowData.forEach((value, key) => {
      handleAction(value, key).catch(setError);
    });
  }, [rowData]);

  return (
    <>
      <Container fluid>
        <div className={`d-flex justify-content-between gap-2 mb-4`}>
          <h1 className="mb-0">{t('title')}</h1>

          <Button onClick={() => setShowAddModal(true)}>{t('add')}</Button>
        </div>

        <Table
          data={tableData}
          showActions
          handleSelectRow={data => setRowData(data)}
          isLoading={isLoading}
        >
          <Table.Actions>
            <Button
              variant="light"
              data-type="download"
            >
              {t('download')}
            </Button>

            <Button
              variant="light"
              data-type="delete"
            >
              <FontAwesomeIcon
                icon={faTrash}
                title={t('delete')}
              />
            </Button>
          </Table.Actions>
        </Table>
      </Container>

      <QrModal
        show={showQrModal}
        handleClose={() => setShowQrModal(false)}
        title={qrData?.title ?? ''}
        qrCodeLink={qrData?.qrCode ?? ''}
        generate
      />

      <AddBackupModal
        show={showAddModal}
        handleClose={() => setShowAddModal(false)}
      />
    </>
  );
};

export default Backup;
