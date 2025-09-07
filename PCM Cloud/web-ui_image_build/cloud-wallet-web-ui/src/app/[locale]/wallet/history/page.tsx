'use client';

import Table, { type TableData } from '@/components/table/Table';
import { useApiData } from '@/service/apiService';
import type { DefaultConfig, HistoryData } from '@/service/types';
import { useTranslations } from 'next-intl';
import { useEffect, useState } from 'react';
import { Col, Container, Row } from 'react-bootstrap';
import css from './history.module.scss';
import { useQueryClient } from '@tanstack/react-query';
import { formatDateString } from '@/utils/dateUtils';
import { useKeycloak } from '@react-keycloak/web';

const History = (): JSX.Element => {
  const { keycloak } = useKeycloak();
  const t = useTranslations('History');

  const config = useQueryClient().getQueryData<DefaultConfig>(['defaultConfig']);
  const [tableData, setTableData] = useState<TableData>();
  const [historyLength, setHistoryLength] = useState<number>(0);
  const { data, isLoading } = useApiData<HistoryData>(
    'historyList',
    `${process.env.API_URL_ACCOUNT_SERVICE}/history/list`,
    { headers: { Authorization: `Bearer ${keycloak.token}` } }
  );

  useEffect(() => {
    if (!data || data.events.length <= 0) return;

    setHistoryLength(data.events.length);

    setTableData({
      head: ['event', 'type', 'userId', 'timestamp'],
      body: data.events
        .map(({ ...history }, i) => {
          return {
            ...history,
            id: `id_${i}`,
            timestamp: formatDateString(history.timestamp),
          };
        })
        .sort((a, b) => (a.timestamp > b.timestamp ? -1 : 1))
        .slice(0, config?.historyLimit),
    });
  }, [data]);

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
        isLoading={isLoading}
      ></Table>

      {tableData && (
        <div className="d-flex justify-content-end">
          <span>
            {t('length', {
              length: tableData?.body.length,
              total: historyLength,
            })}
          </span>
        </div>
      )}
    </Container>
  );
};

export default History;
