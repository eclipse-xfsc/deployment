'use client';

import { useApiData } from '@/service/apiService';
import type { DidData } from '@/service/types';
import { useKeycloak } from '@react-keycloak/web';
import { useLocale, useTranslations } from 'next-intl';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { Button, FormGroup, FormSelect } from 'react-bootstrap';
import { toast } from 'react-toastify';

interface DidSelectionProps {
  getSelectedDID: (did: string) => void;
}

const DidSelection = ({ getSelectedDID }: DidSelectionProps): JSX.Element => {
  const t = useTranslations('Presentation');
  const { keycloak } = useKeycloak();
  const [selectedDID, setSelectedDID] = useState<string>('');
  const { data: didData } = useApiData<DidData>('didList', `${process.env.API_URL_ACCOUNT_SERVICE}/kms/did/list`, {
    headers: { Authorization: `Bearer ${keycloak.token}` },
  });
  const router = useRouter();
  const locale = useLocale();

  useEffect(() => {
    if (!didData) return;

    if (didData?.list.length < 1) {
      toast.info(<ToastRedirectDidCreation />, {
        autoClose: false,
      });
    }
  }, [didData]);

  const handleDIDSelection = (did: string): void => {
    setSelectedDID(did);
    getSelectedDID(did);
  };

  const ToastRedirectDidCreation = (): JSX.Element => {
    return (
      <div className="d-flex flex-column gap-2">
        <strong>{t('create-did')}</strong>
        <Button
          variant="light"
          onClick={() => {
            router.push(`/${locale}/wallet/did`);
          }}
        >
          {t('go-to-did-creation')}
        </Button>
      </div>
    );
  };

  return (
    <FormGroup>
      <FormSelect
        value={selectedDID}
        onChange={e => handleDIDSelection(e.target.value)}
      >
        <option value="">{t('select-did')}</option>
        {didData?.list.map(did => (
          <option
            key={did.id}
            value={did.id}
          >
            {did.did}
          </option>
        ))}
      </FormSelect>
    </FormGroup>
  );
};

export default DidSelection;
