'use client';

import { useLocale, useTranslations } from 'next-intl';
import css from './issuance.module.scss';
import { Button, Col, Container, Row } from 'react-bootstrap';
import type { CredentialOffer, IssuanceData, SchemaData } from '@/service/types';
import { genericFetch, useApiData } from '@/service/apiService';
import { type FormEvent, useContext, useEffect, useState } from 'react';
import Table, { type TableBody, type TableBodyMap, type TableData } from '@/components/table/Table';
import { AppContext } from '@/store/AppContextProvider';
import SchemaModal from '@/components/schema-modal/SchemaModal';
import { type IChangeEvent } from '@rjsf/core';
import { type RJSFSchema } from '@rjsf/utils';
import { toast } from 'react-toastify';
import { getDetailedDisplay, getDisplayName } from '@/utils/objectUtils';
import { useKeycloak } from '@react-keycloak/web';

const Issuance = (): JSX.Element => {
  const t = useTranslations('Issuance');
  const { keycloak } = useKeycloak();
  const { setError } = useContext(AppContext);
  const locale = useLocale();

  const [tableData, setTableData] = useState<TableData>();
  const [rowData, setRowData] = useState<TableBodyMap>();
  const [showModal, setShowModal] = useState(false);
  const [credentialOfferLink, setCredentialOfferLink] = useState('');
  const { data, isLoading } = useApiData<IssuanceData[]>(
    'schemaList',
    `${process.env.API_URL_ACCOUNT_SERVICE}/credentials/schemas`,
    { headers: { Authorization: `Bearer ${keycloak.token}` } }
  );

  useEffect(() => {
    if (!data || data.length <= 0) return;

    setTableData({
      head: ['', 'name', 'format', 'fields'],
      body: [data].flatMap(item => {
        return Object.keys(item).map(key => {
          // @ts-expect-error
          const { display, credential_definition, format } = item[key];
          return {
            logo: '/xfsc1.png',
            id: key,
            name: getDetailedDisplay(display, locale).name,
            format,
            fields: Object.keys(credential_definition.credentialSubject)
              .map(fieldKey => getDisplayName(credential_definition.credentialSubject, fieldKey, locale))
              .join(', '),
          };
        });
      }),
    });
  }, [data]);

  useEffect(() => {
    if (!rowData) return;

    if (rowData.get('select')) setShowModal(true);
  }, [rowData]);

  const getSelectedData = (rowData: TableBody, data: IssuanceData[]): Record<string, SchemaData> => {
    const key = rowData.id;
    const schemaData = data.find(item => item[key]);

    if (!schemaData) {
      setError(Error('Schema not found'));
      // @ts-expect-error
      return;
    }

    const schema = schemaData[key].schema;

    // @ts-expect-error
    delete schema.data.$id;
    // @ts-expect-error
    delete schema.data.$schema;

    return {
      [key]: {
        data: {
          ...schema.data,
          properties: {
            ...schema.data.properties,
            pin_otp: {
              title: 'Add One Time Code',
              type: 'boolean',
            },
          },
        },
        ui: {
          ...schema.ui,
          'ui:order': [...(schema.ui['ui:order'] ?? []), 'pin_otp'],
        },
      },
    };
  };

  const handleOnSubmit = (data: IChangeEvent<any, RJSFSchema, any>, key: string, event: FormEvent<any>): void => {
    event.preventDefault();

    const getIssuedLink = async (): Promise<CredentialOffer> => {
      return await genericFetch<CredentialOffer>(`${process.env.API_URL_ACCOUNT_SERVICE}/credentials/issue`, {
        headers: { Authorization: `Bearer ${keycloak.token}` },
        body: JSON.stringify({
          payload: {
            ...data.formData,
          },
          type: key,
        }),
        method: 'POST',
      });
    };

    getIssuedLink()
      .then(data => {
        toast.success(t('success-message'));
        setCredentialOfferLink(data.credential_offer);
      })
      .catch(setError);
  };

  return (
    <>
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

        <Table
          data={tableData}
          showActions
          handleSelectRow={data => setRowData(data)}
          isLoading={isLoading}
        >
          <Table.Actions>
            <Button
              variant="light"
              data-type="select"
            >
              {t('select')}
            </Button>
          </Table.Actions>
        </Table>
      </Container>

      {rowData?.get('select') && data && (
        <SchemaModal
          show={showModal}
          handleClose={() => setShowModal(false)}
          data={getSelectedData(rowData.get('select')!, Array.isArray(data) ? data : [data])}
          onSubmit={handleOnSubmit}
          offeringLink={credentialOfferLink}
        />
      )}
    </>
  );
};

export default Issuance;
