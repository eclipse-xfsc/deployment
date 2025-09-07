'use client';

import QrModal from '@/components/qr-modal/QrModal';
import Table, { type TableBody, type TableBodyMap, type TableData } from '@/components/table/Table';
import { genericFetch, useApiData } from '@/service/apiService';
import type { DevicesData } from '@/service/types';
import { AppContext } from '@/store/AppContextProvider';
import { faBan, faCirclePlus, faTrash } from '@fortawesome/free-solid-svg-icons';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { useTranslations } from 'next-intl';
import { useContext, useEffect, useState } from 'react';
import { Button, Col, Container, Row } from 'react-bootstrap';
import css from './pairing-management.module.scss';
import DetailsModal from '@/components/details-modal/DetailsModal';
import { toast } from 'react-toastify';
import { useKeycloak } from '@react-keycloak/web';
import { useQueryClient } from '@tanstack/react-query';

const PairingManagement = (): JSX.Element => {
  const t = useTranslations('SettingsPairingManagement');
  const { keycloak } = useKeycloak();
  const { setError } = useContext(AppContext);
  const queryClient = useQueryClient();

  const [tableData, setTableData] = useState<TableData>();
  const [showModal, setShowModal] = useState(false);
  const [showSeeDetails, setShowSeeDetails] = useState(false);
  const [rowData, setRowData] = useState<TableBodyMap>();
  const [qrCode, setQrCode] = useState('');
  const { data, isLoading } = useApiData<DevicesData[]>(
    'devicesList',
    `${process.env.API_URL_ACCOUNT_SERVICE}/devices/list`,
    { headers: { Authorization: `Bearer ${keycloak.token}` } }
  );

  useEffect(() => {
    if (!data || data.length <= 0) return;

    // make sure it's an array of objects (only used for the mock data)
    const devicesData = Array.isArray(data) ? data : [data];

    setTableData({
      head: ['remoteDid', 'protocol', 'topic', 'eventType', 'group'],
      body: devicesData.map(({ ...credentials }) => {
        return {
          id: credentials.remoteDid,
          remoteDid: credentials.remoteDid,
          protocol: credentials.protocol,
          topic: credentials.topic,
          eventType: credentials.eventType,
          group: credentials.group,
        };
      }),
    });
  }, [data]);

  useEffect(() => {
    if (!rowData) return;

    const handleAction = async (value: TableBody, key: string): Promise<void> => {
      switch (key) {
        case 'see-details':
          setShowSeeDetails(true);
          break;
        case 'block':
          await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/devices/block/${value.id}`, {
            headers: { Authorization: `Bearer ${keycloak.token}` },
            method: 'POST',
          })
            .then(() => {
              void queryClient.invalidateQueries({ queryKey: ['devicesList'] });
              toast.success(t('block-success'));
            })
            .catch(setError);
          break;
        case 'delete':
          await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/devices/${value.id}`, {
            headers: { Authorization: `Bearer ${keycloak.token}` },
            method: 'DELETE',
          })
            .then(() => {
              void queryClient.invalidateQueries({ queryKey: ['devicesList'] });
              toast.success(t('delete-success'));
            })
            .catch(setError);
          break;
      }
    };

    rowData.forEach((value, key) => {
      handleAction(value, key).catch(setError);
    });
  }, [rowData]);

  const handleQrCodeClick = (): void => {
    genericFetch<string>(`${process.env.API_URL_ACCOUNT_SERVICE}/devices/link`, {
      headers: {
        Authorization: `Bearer ${keycloak.token}`,
      },
    })
      .then(data => {
        setQrCode(data ?? '');
        setShowModal(true);
      })
      .catch(error => setError(error));
  };

  return (
    <>
      <Container fluid>
        <Row className="mb-4">
          <Col
            md="6"
            sm="12"
            className={`${css['flex-center']} justify-content-between gap-2 mb-2`}
          >
            <div className="d-flex gap-2 align-items-center">
              <h1 className="mb-0">{t('title')}</h1>
              <Button
                variant="light"
                className={`rounded-circle ${css['btn-add']}`}
                onClick={handleQrCodeClick}
              >
                <FontAwesomeIcon
                  icon={faCirclePlus}
                  className={css.icon}
                />
              </Button>
            </div>
          </Col>
        </Row>

        <Table
          data={tableData}
          isLoading={isLoading}
          showActions
          handleSelectRow={data => setRowData(data)}
        >
          <Table.Actions>
            <Button
              variant="light"
              data-type="see-details"
            >
              {t('see-details')}
            </Button>

            <Button
              variant="light"
              data-type="block"
            >
              <FontAwesomeIcon
                icon={faBan}
                title={t('block')}
              />
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
        show={showModal}
        handleClose={() => setShowModal(false)}
        title="Device QR-Code"
        qrCodeLink={qrCode}
        generate
      />

      {rowData?.get('see-details') && data && (
        <DetailsModal
          show={showSeeDetails}
          handleClose={() => setShowSeeDetails(false)}
          data={
            new Map<string, TableBody>([
              [
                'see-details',
                data
                  .filter(({ remoteDid }) => remoteDid === rowData.get('see-details')?.id)
                  .map(({ ...credentials }) => ({
                    id: credentials.remoteDid,
                    ...credentials,
                  }))[0],
              ],
            ])
          }
          title={t('connection-details')}
        />
      )}
    </>
  );
};

export default PairingManagement;
