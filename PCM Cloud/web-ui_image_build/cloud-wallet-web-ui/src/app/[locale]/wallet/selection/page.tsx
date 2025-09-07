'use client';

import Divider from '@/components/divider/Divider';
import Table, { type TableBodyMap, type TableData } from '@/components/table/Table';
import { useApiData } from '@/service/apiService';
import type { PresentationDefinitionData } from '@/service/types';
import { useTranslations } from 'next-intl';
import { useEffect, useState } from 'react';
import { Button, Col, Container, Row } from 'react-bootstrap';
import css from './selection.module.scss';
import PresentationSelection from '@/components/presentation-selection/PresentationSelection';
import { useKeycloak } from '@react-keycloak/web';

const Selection = (): JSX.Element => {
  const t = useTranslations('Presentation');
  const { keycloak } = useKeycloak();
  const { data: definitionData, isLoading: isLoadingDefinition } = useApiData<PresentationDefinitionData[]>(
    'presentationDefinitionList',
    `${process.env.API_URL_ACCOUNT_SERVICE}/presentations/selection/all`,
    { headers: { Authorization: `Bearer ${keycloak.token}` } }
  );
  const [rowData, setRowData] = useState<TableBodyMap>();
  const [tableData, setTableData] = useState<TableData>();

  useEffect(() => {
    if (!definitionData || definitionData.length <= 0) return;

    // make sure it's an array of objects (only used for the mock data)
    const presentationDefinitionData = Array.isArray(definitionData) ? definitionData : [definitionData];

    setTableData({
      head: ['id', 'format'],
      body: presentationDefinitionData.map(({ ...definition }) => {
        let format = '';

        if (definition.input_descriptors?.[0].format) {
          format = Object.keys(definition.input_descriptors[0].format).join(', ');
        }

        return {
          id: definition.id,
          format,
        };
      }),
    });
  }, [definitionData]);

  useEffect(() => {
    if (!definitionData) return;

    const urlParams = localStorage.getItem('urlParams');

    if (urlParams) {
      const { presentation } = JSON.parse(urlParams);

      setRowData(new Map([['select', getPresentationDefinition(presentation)]]));
    }
  }, [definitionData]);

  const handleSetDataRow = (data: TableBodyMap): void => {
    localStorage.setItem('urlParams', JSON.stringify({ presentation: data.get('select')?.id }));

    setRowData(data);
  };

  const getPresentationDefinition = (id: string): PresentationDefinitionData => {
    // @ts-expect-error
    if (!definitionData) return;

    // @ts-expect-error
    return definitionData?.find(definition => definition.id === id);
  };

  return (
    <Container fluid>
      <Row>
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

      <Divider className="my-2" />

      {rowData?.get('select') ? (
        <PresentationSelection presentationDefinition={getPresentationDefinition(rowData.get('select')!.id)} />
      ) : (
        <Table
          data={tableData}
          showActions
          showId
          isLoading={isLoadingDefinition}
          handleSelectRow={data => handleSetDataRow(data)}
        >
          <Table.Actions>
            <div className={`d-flex gap-2`}>
              <Button
                variant="light"
                data-type="select"
              >
                {t('select-presentation')}
              </Button>
            </div>
          </Table.Actions>
        </Table>
      )}
    </Container>
  );
};

export default Selection;
