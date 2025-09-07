import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import CredentialColumn from '../credential-column/CredentialColumn';
import css from './PresentationSelection.module.scss';
import { Button, Tab, Tabs } from 'react-bootstrap';
import { faRightLeft, faRightToBracket } from '@fortawesome/free-solid-svg-icons';
import DidSelection from '../did-selection/DidSelection';
import CardDocument from '../card-document/CardDocument';
import type { CredentialData, Description, PresentationDefinitionData, VerifiableCredentials } from '@/service/types';
import { useDrop } from 'react-dnd';
import { useContext, useEffect, useState } from 'react';
import { genericFetch } from '@/service/apiService';
import { AppContext } from '@/store/AppContextProvider';
import { useLocale, useTranslations } from 'next-intl';
import { toast } from 'react-toastify';
import { useRouter } from 'next/navigation';
import { useKeycloak } from '@react-keycloak/web';

interface PresentationSelectionProps {
  presentationDefinition: PresentationDefinitionData;
}

interface CredentialDescription {
  credential: CredentialData;
  description: Description;
  id: string;
}

const PresentationSelection = ({ presentationDefinition }: PresentationSelectionProps): JSX.Element => {
  const { keycloak } = useKeycloak();
  const [filteredData, setFilteredData] = useState<VerifiableCredentials[]>([]);
  const { setError } = useContext(AppContext);
  const t = useTranslations('Presentation');
  const [{ isOver }, drop] = useDrop({
    accept: 'credential',
    drop: (item: { credential: CredentialData; description: Description; id: string }) => {
      setPresentation([
        ...presentation,
        {
          credential: item.credential,
          description: item.description,
          id: item.id,
        },
      ]);
      setFilteredData(filteredData.filter(credential => !Object.keys(credential.credentials).includes(item.id)));
    },
    collect: monitor => ({
      isOver: !!monitor.isOver(),
    }),
  });
  const [presentation, setPresentation] = useState<CredentialDescription[]>([]);
  const [selectedDID, setSelectedDID] = useState<string>('');
  const router = useRouter();
  const locale = useLocale();

  useEffect(() => {
    return () => {
      localStorage.removeItem('urlParams');
      setPresentation([]);
    };
  }, []);

  useEffect(() => {
    const presentationSelection = async (): Promise<VerifiableCredentials[]> => {
      return await genericFetch(
        `${process.env.API_URL_ACCOUNT_SERVICE}/presentations/selection/${presentationDefinition.id}`,
        {
          headers: {
            Authorization: `Bearer ${keycloak.token}`,
          },
        }
      );
    };

    presentationSelection()
      .then(data => {
        if (!data) {
          router.push(`/${locale}/wallet/credentials`);
          toast.error(t('no-credentials'));
        }

        setFilteredData(data || []);
      })
      .catch(error => {
        setError(error);
      });
  }, []);

  const handleTransmitPresentation = (): void => {
    const transmitPresentation = async (): Promise<any> => {
      return await genericFetch(
        `${process.env.API_URL_ACCOUNT_SERVICE}/presentations/proof/${presentationDefinition.id}`,
        {
          headers: {
            Authorization: `Bearer ${keycloak.token}`,
          },
          method: 'POST',
          body: JSON.stringify({
            signKeyId: selectedDID,
            filters: presentation.map<VerifiableCredentials>(credential => {
              return {
                description: {
                  id: presentationDefinition.id,
                  name: presentationDefinition.name,
                  purpose: presentationDefinition.purpose,
                  format: presentationDefinition.format ? Object.keys(presentationDefinition.format).join(',') : '',
                },
                credentials: {
                  [credential.id]: credential.credential,
                },
              };
            }),
          }),
        }
      );
    };

    transmitPresentation()
      .then(() => {
        toast.success(t('presentation-transmitted'));
        router.push(`/${locale}/wallet/presentations`);
      })
      .catch(error => {
        setError(error);
      });
  };

  return (
    <div className={`d-flex justify-content-between ${css['selection-wrapper']}`}>
      <div className={css['cards-container']}>
        <Tabs
          className={css.tabs}
          justify
        >
          {filteredData?.map(credential => (
            <Tab
              eventKey={credential.description.id}
              title={credential.description.id}
              key={credential.description.id}
              className={css['tab-container']}
              style={{
                minWidth: '330px',
              }}
            >
              <CredentialColumn
                credential={credential}
                movable={true}
              />
            </Tab>
          ))}
        </Tabs>
      </div>

      {filteredData.length !== 0 && (
        <div className="align-self-center mx-3">
          <FontAwesomeIcon
            icon={faRightLeft}
            size="2x"
          />
        </div>
      )}

      <div
        className={`${css['selection-container']}`}
        ref={drop}
      >
        <div className="d-flex align-items-center justify-content-between">
          <DidSelection getSelectedDID={did => setSelectedDID(did)} />

          <Button
            variant="primary"
            className={`${css['flex-center']} gap-1`}
            disabled={selectedDID === '' || filteredData.length !== 0}
            onClick={handleTransmitPresentation}
          >
            <span>{t('confirm')}</span>
            <FontAwesomeIcon
              icon={faRightToBracket}
              className={css.icon}
            />
          </Button>
        </div>

        <div className={`${css['selection-box']} ${isOver ? css['is-over'] : ''}`}>
          <h2 className={`${css['empty-presentation']}`}>{t('drag-and-drop')}</h2>
          {presentation.length > 0 && (
            <div className={`${css['presentation-box']}`}>
              {presentation.map(credential => (
                <CardDocument
                  key={credential.id}
                  credential={credential.credential}
                  description={credential.description}
                  id={credential.id}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default PresentationSelection;
