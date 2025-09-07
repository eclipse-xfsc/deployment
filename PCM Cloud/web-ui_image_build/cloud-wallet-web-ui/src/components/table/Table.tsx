'use client';

import { Table as BTable, Image } from 'react-bootstrap';
import css from './Table.module.scss';
import LoadingSpinner from '../loading-spinner/LoadingSpinner';
import NoData from '../no-data/NoData';

export interface TableBody {
  id: string;
  [key: string]: any;
  logo?: string;
}

export interface TableData {
  head: string[];
  body: TableBody[];
}

export type TableBodyMap = Map<string, TableBody>;

interface TableProps {
  data?: TableData;
  children?: React.ReactNode;
  showId?: boolean;
  showActions?: boolean;
  handleSelectRow?: (data: TableBodyMap) => void;
  isLoading?: boolean;
  filterActions?: (actions: TableBody) => boolean;
}

const Table = ({
  data,
  children,
  showId = false,
  showActions = false,
  handleSelectRow,
  isLoading = false,
  filterActions,
}: TableProps): JSX.Element => {
  const handleClickRow = (e: MouseEvent): void => {
    const target = e.target as HTMLElement;

    let buttonElement: HTMLElement | null = target;

    while (buttonElement && buttonElement.tagName !== 'BUTTON') {
      buttonElement = buttonElement.parentElement;
    }

    if (!buttonElement) return;

    const type = buttonElement.getAttribute('data-type') ?? '';
    const id = buttonElement.closest('tr')?.id;
    const selectedRow = data?.body.find(row => row.id === id);

    if (selectedRow) {
      handleSelectRow?.(new Map([[type, selectedRow]]));
    }
  };

  return (
    <>
      {data && !isLoading ? (
        <BTable
          className={`${css.table}`}
          responsive
          borderless
        >
          <thead>
            <tr>
              {data.head.map((head, i) => {
                if (head === 'id' && !showId) return null;
                return <th key={i}>{head}</th>;
              })}
              {showActions && <th></th>}
            </tr>
          </thead>
          <tbody>
            {data.body.map(body => (
              <tr
                key={body.id}
                id={body.id}
              >
                {Object.keys(body).map((key, i) => {
                  if (typeof body[key] === 'object') return null;
                  if (key === 'id' && !showId) return null;

                  if (key === 'logo') {
                    return (
                      <td
                        key={i}
                        className={css['table-cell']}
                      >
                        <Image
                          src={body[key]}
                          alt={body[key]}
                          className={css.logo}
                        />
                      </td>
                    );
                  }

                  return (
                    <td
                      key={i}
                      className={css['table-cell']}
                    >
                      {body[key]}
                    </td>
                  );
                })}

                {showActions && (
                  <td
                    className={`${css.actions} ${filterActions?.(body) ? 'd-none' : ''}`}
                    onClick={e => handleClickRow(e as unknown as MouseEvent)}
                  >
                    {children}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </BTable>
      ) : isLoading ? (
        <div className={`${css['flex-center']}`}>
          <LoadingSpinner />
        </div>
      ) : (
        <NoData />
      )}
    </>
  );
};

Table.Actions = ({ children }: { children: React.ReactNode }) => {
  return children;
};

export default Table;
