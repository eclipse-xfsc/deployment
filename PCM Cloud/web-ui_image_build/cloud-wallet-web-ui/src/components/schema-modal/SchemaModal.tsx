'use client';

import type { SchemaData } from '@/service/types';
import Form, { type IChangeEvent } from '@rjsf/core';
import { type RJSFSchema } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import { useTranslations } from 'next-intl';
import { type FormEvent, useState, useEffect } from 'react';
import { Button, Modal, ModalBody, ModalHeader, ModalTitle } from 'react-bootstrap';
import QRCode from 'react-qr-code';
import { toast } from 'react-toastify';

interface SchemaModalProps {
  show: boolean;
  handleClose: () => void;
  data: Record<string, SchemaData>;
  onSubmit: (data: IChangeEvent<any, RJSFSchema, any>, key: string, event: FormEvent<any>) => void;
  offeringLink: string;
}

const SchemaModal = ({ show, handleClose, data, onSubmit, offeringLink }: SchemaModalProps): JSX.Element => {
  const t = useTranslations('Issuance');
  const [formData, setFormData] = useState({});
  const [isSubmitted, setIsSubmitted] = useState(false);

  useEffect(() => {
    return () => {
      setFormData({});
      setIsSubmitted(false);
    };
  }, []);

  const handleSubmit = (formData: IChangeEvent<any, RJSFSchema, any>, event: FormEvent<any>): void => {
    const key = Object.keys(data)[0];
    onSubmit(formData, key, event);
    setIsSubmitted(true);
  };

  return (
    <Modal
      show={show}
      onHide={handleClose}
      centered
    >
      <ModalHeader closeButton>
        <ModalTitle>{t('schema')}</ModalTitle>
      </ModalHeader>
      <ModalBody>
        {data[Object.keys(data)[0]] && !isSubmitted && (
          <Form
            schema={data[Object.keys(data)[0]].data}
            uiSchema={data[Object.keys(data)[0]].ui}
            onChange={newFormData => setFormData(newFormData.formData ?? {})}
            onSubmit={handleSubmit}
            formData={formData}
            validator={validator}
          />
        )}
        {isSubmitted && (
          <div className="d-flex flex-column gap-4">
            <div className="align-self-center">
              <QRCode
                value={offeringLink}
                size={300}
              />
            </div>

            <p>{t('scan-qr')}</p>
            <Button
              variant="primary"
              onClick={() => {
                void navigator.clipboard.writeText(offeringLink);
                toast.success(t('copied'));
              }}
            >
              {t('copy')}
            </Button>
          </div>
        )}
      </ModalBody>
    </Modal>
  );
};

export default SchemaModal;
