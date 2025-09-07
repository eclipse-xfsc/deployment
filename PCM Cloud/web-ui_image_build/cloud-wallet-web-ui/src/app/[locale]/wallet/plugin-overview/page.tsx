'use client';

import DetailsModal from '@/components/details-modal/DetailsModal';
import Table, { type TableBodyMap, type TableData } from '@/components/table/Table';
import { useTranslations } from 'next-intl';
import { useEffect, useState } from 'react';
import { Button, Col, Container, Row } from 'react-bootstrap';
import css from './plugin-overview.module.scss';
import { type Plugin } from '@/components/side-menu/WalletSideMenu';
import { useQueryClient } from '@tanstack/react-query';

export interface PluginWrapper {
  plugins: Plugin[];
}

const PluginOverview = (): JSX.Element => {
  const data = useQueryClient().getQueryData<PluginWrapper[]>(['pluginDiscovery']);
  const [tableData, setTableData] = useState<TableData>();
  const t = useTranslations('SettingsPluginOverview');
  const [showModal, setShowModal] = useState(false);
  const [rowData, setRowData] = useState<TableBodyMap>();

  useEffect(() => {
    if (!rowData) return;

    rowData.get('see-details') && setShowModal(true);
  }, [rowData]);

  useEffect(() => {
    if (!data || data.length <= 0) return;

    // make sure it's an array of objects (only used for the mock data)
    const pluginsData = Array.isArray(data) ? data : [data];

    setTableData({
      head: ['name', 'route', 'url'],
      body: pluginsData[0].plugins.map(({ ...plugin }) => {
        console.log(plugin);
        return {
          id: plugin.name,
          ...plugin,
        };
      }),
    });
  }, [data]);

  const handleCloseModal = (): void => {
    setShowModal(false);
  };

  return (
    <Container fluid>
      <Row className="mb-4">
        <Col
          md="6"
          sm="12"
          className={`${css['flex-center']} justify-content-between gap-2 mb-2`}
        >
          <div className="d-flex gap-2 align-items-center">
            <h1 className="mb-0">{t('title')}</h1>
          </div>
        </Col>
      </Row>

      <Table
        data={tableData}
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
        </Table.Actions>
      </Table>

      {rowData && (
        <DetailsModal
          show={showModal}
          handleClose={handleCloseModal}
          data={`${process.env.API_URL}/dynamic/plugins${rowData.get('see-details')?.url}/application/metadata`}
          title={t('plugin-details')}
        />
      )}
    </Container>
  );
};

export default PluginOverview;
