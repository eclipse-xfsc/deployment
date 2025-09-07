'use client';

import type { CredentialInPresentation, VerifiableCredentials } from '@/service/types';
import CardDocument from '../card-document/CardDocument';
import css from './CredentialColumn.module.scss';
import PresentationModal from '../presentation-modal/PresentationModal';
import { useMemo, useState } from 'react';

interface CredentialColumnProps {
  credential: VerifiableCredentials;
  movable?: boolean;
  presentation?: CredentialInPresentation;
}

const CredentialColumn = ({ credential, movable = false, presentation }: CredentialColumnProps): JSX.Element => {
  const [showModal, setShowModal] = useState(false);

  const columns = useMemo(
    () =>
      Object.keys(credential.credentials).reduce<string[][]>((acc, key, index) => {
        const columnIndex = Math.floor(index / 5);

        if (!acc[columnIndex]) {
          acc[columnIndex] = [];
        }

        acc[columnIndex].push(key);

        return acc;
      }, []),
    [credential.credentials]
  );

  const CredentialColumnCard = ({
    column,
    credential,
    movable,
  }: {
    column: string[];
    credential: VerifiableCredentials;
    movable: boolean;
  }): JSX.Element => (
    <div className={`p-2 ${css['card-container']}`}>
      {column.map(key => (
        <CardDocument
          key={key}
          credential={credential.credentials[key]}
          description={credential.description}
          id={key}
          movable={movable}
        />
      ))}
    </div>
  );

  return (
    <>
      {columns.map((column, columnIndex) => (
        <div
          key={columnIndex}
          className={`${css['card-column']} ${movable ? css.presentation : ''}`}
        >
          {!movable && (
            <div
              className={`${css['column-header']} ${presentation ? css['cursor-pointer'] : ''}`}
              onClick={presentation && (() => setShowModal(true))}
            >
              <h2 className="text-white">{credential.description.name ?? credential.description.id}</h2>
            </div>
          )}
          <CredentialColumnCard
            column={column}
            credential={credential}
            movable={movable}
          />
        </div>
      ))}

      {presentation && (
        <PresentationModal
          show={showModal}
          handleClose={() => setShowModal(false)}
          data={presentation}
          title={credential.description.name ?? credential.description.id}
        />
      )}
    </>
  );
};

export default CredentialColumn;
