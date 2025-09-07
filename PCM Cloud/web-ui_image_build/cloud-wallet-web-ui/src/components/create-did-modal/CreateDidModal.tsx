import { useApiData } from '@/service/apiService';
import { useKeycloak } from '@react-keycloak/web';
import { useTranslations } from 'next-intl';
import React, { type FormEvent, useState } from 'react';
import { Button, Form, FormGroup, FormSelect, Modal, ModalBody, ModalHeader, ModalTitle } from 'react-bootstrap';
import { toast } from 'react-toastify';

interface CreateDidModalProps {
  show: boolean;
  handleClose: () => void;
  onSubmit: (did: string) => void;
}

const CreateDidModal = ({ show, handleClose, onSubmit }: CreateDidModalProps): JSX.Element => {
  const { keycloak } = useKeycloak();
  const [selectedDID, setSelectedDID] = useState<string>('');
  const t = useTranslations('Did');
  const { data } = useApiData<string[]>('keyTypes', `${process.env.API_URL_ACCOUNT_SERVICE}/kms/keyTypes`, {
    headers: { Authorization: `Bearer ${keycloak.token}` },
  });

  const handleAcceptOffering = (event: FormEvent<HTMLFormElement>): void => {
    event.preventDefault();

    if (selectedDID === '') {
      toast.error(t('empty-key-type'));
      return;
    }

    onSubmit(selectedDID);
    setSelectedDID('');
    handleClose();
  };

  return (
    <Modal
      show={show}
      onHide={handleClose}
      centered
    >
      <ModalHeader closeButton>
        <ModalTitle>{t('add')}</ModalTitle>
      </ModalHeader>
      <ModalBody>
        <Form
          onSubmit={handleAcceptOffering}
          className="d-flex justify-content-between gap-1 align-items-end"
        >
          <FormGroup className="flex-grow-1">
            <FormSelect
              value={selectedDID}
              onChange={e => setSelectedDID(e.target.value)}
            >
              <option value="">{t('key-type-placeholder')}</option>
              {data?.map(keyType => (
                <option
                  key={keyType}
                  value={keyType}
                >
                  {keyType}
                </option>
              ))}
            </FormSelect>
          </FormGroup>
          <Button
            variant="primary"
            type="submit"
            onClick={handleClose}
          >
            {t('submit')}
          </Button>
        </Form>
      </ModalBody>
    </Modal>
  );
};

export default CreateDidModal;
