'use client';

import { Button, Col, Container, Form, FormControl, FormGroup, FormLabel, FormSelect, Row } from 'react-bootstrap';
import css from './settings.module.scss';
import Divider from '@/components/divider/Divider';
import { useTranslations } from 'next-intl';
import { useContext, useEffect, useState } from 'react';
import { AppContext } from '@/store/AppContextProvider';
import { type DefaultConfig } from '@/service/types';
import { useQueryClient } from '@tanstack/react-query';
import { toast } from 'react-toastify';
import { genericFetch, useApiData } from '@/service/apiService';
import { useKeycloak } from '@react-keycloak/web';

const Settings = (): JSX.Element => {
  const t = useTranslations('Settings');
  const { keycloak } = useKeycloak();
  const queryClient = useQueryClient();
  const data = queryClient.getQueryData<DefaultConfig>(['defaultConfig']);
  const { data: userInfo, isLoading: isLoadingUserInfo } = useApiData<any>(
    'userInfoData',
    `${process.env.API_URL_ACCOUNT_SERVICE}/configurations/getUserInfo`,
    { headers: { Authorization: `Bearer ${keycloak.token}` } }
  );
  const { setError } = useContext(AppContext);
  const [formData, setFormData] = useState<DefaultConfig>({
    historyLimit: 0,
    language: '',
  });

  useEffect(() => {
    if (data) {
      setFormData(data);
    }
  }, [data]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>): void => {
    const { name, value } = e.target;
    setFormData(prevData => ({
      ...prevData,
      [name]: value,
    }));
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>): void => {
    let hasErrors = false;
    e.preventDefault();

    const saveData = async (): Promise<void> => {
      const historyLimit = Number(formData.historyLimit);
      hasErrors = true;

      if (historyLimit == null) {
        toast.error(t('empty-history-limit'));
        return;
      }

      if (isNaN(historyLimit)) {
        toast.error(t('invalid-history-limit'));
        return;
      }

      if (historyLimit < 0) {
        toast.error(t('negative-history-limit'));
        return;
      }

      hasErrors = false;

      await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/configurations/save`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${keycloak.token}`,
        },
        body: JSON.stringify({
          language: formData.language,
          historyLimit,
        }),
      });
    };

    saveData()
      .then(async () => {
        if (hasErrors) return;

        await queryClient.invalidateQueries({ queryKey: ['defaultConfig'] });
        toast.success(t('save-success'));
      })
      .catch(error => {
        setError(error as Error);
      });
  };

  return (
    <Container
      fluid
      className="mb-5"
    >
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

      <Form
        className="mt-3 p-1 d-grid gap-3"
        // eslint-disable-next-line @typescript-eslint/no-misused-promises
        onSubmit={handleSubmit}
      >
        <FormGroup>
          <FormLabel>
            <strong>{t('user-id')}:</strong>
          </FormLabel>
          <FormControl
            type="text"
            value={isLoadingUserInfo ? '' : userInfo?.sub}
            disabled
          />
        </FormGroup>
        <FormGroup>
          <FormLabel>
            <strong>{t('language')}:</strong>
          </FormLabel>
          <FormSelect
            name="language"
            value={formData.language.toLowerCase()}
            onChange={handleInputChange}
          >
            <option value="en">English</option>
            <option value="de">Deutsch</option>
          </FormSelect>
        </FormGroup>

        <FormGroup>
          <FormLabel>
            <strong>{t('history-limit')}:</strong>
          </FormLabel>
          <FormControl
            type="number"
            name="historyLimit"
            value={formData.historyLimit}
            onChange={(e: React.ChangeEvent<any>) => handleInputChange(e)}
          />
        </FormGroup>

        <Button
          variant="primary"
          type="submit"
        >
          {t('save')}
        </Button>
      </Form>
    </Container>
  );
};

export default Settings;
